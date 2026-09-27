"""Tally one headless run: tokens and wall time per stage, from the session transcripts.

Usage: python3 tally.py <run dir> [--raw <dir> --tag <tag>]

<run dir> holds stream.jsonl (claude -p --output-format stream-json --verbose), start and end.
Sources, per number:
- The session id, model and the final result come from stream.jsonl (init and result events).
- Tokens per agent come from the transcripts Claude Code writes: ~/.claude/projects/<slug>/<session>.jsonl
  for the main thread and <session>/subagents/agent-*.jsonl (+ .meta.json for the agent type) for
  each subagent. One API response can span several transcript lines; usage is counted once per
  message id. The check line compares the sum with the result event's modelUsage, which includes
  subagents (its `usage` field is the main thread only).
- Main-thread stages are cut at the orchestrator's own tool calls: messages before the first
  reviewer dispatch are prep + triage; from that message to the first verifier dispatch,
  dispatch + collect + merge; from there on, verification collect + synthesis.
- Wall time per stage: first to last transcript timestamp of that stage; total from the result
  event's duration_ms and the wrapper's start and end.
With --raw, each reviewer's final answer is written to <dir>/<tag>-<agent>.md for the anchor check.
"""
import glob, json, os, re, sys
from datetime import datetime

KEYS = ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens", "output_tokens")
SHORT = {"input_tokens": "in", "cache_creation_input_tokens": "cw", "cache_read_input_tokens": "cr", "output_tokens": "out"}


def ts(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()


def load(path):
    return [json.loads(l) for l in open(path) if l.strip()]


def messages(events):
    """Assistant messages in order, usage once per message id, with their tool_use blocks and times."""
    order, by = [], {}
    for e in events:
        if e.get("type") != "assistant":
            continue
        m = e["message"]
        mid = m["id"]
        if mid not in by:
            by[mid] = {"usage": {}, "tools": [], "t0": e.get("timestamp"), "t1": e.get("timestamp"), "text": ""}
            order.append(mid)
        rec = by[mid]
        rec["usage"] = m.get("usage") or rec["usage"]
        rec["t1"] = e.get("timestamp") or rec["t1"]
        for b in m.get("content", []):
            if b.get("type") == "tool_use":
                rec["tools"].append(b)
            elif b.get("type") == "text":
                rec["text"] += b.get("text", "")
    return [by[i] for i in order]


def add(tot, u):
    for k in KEYS:
        tot[k] = tot.get(k, 0) + (u.get(k) or 0)


def total(u):
    return sum(u.get(k, 0) for k in KEYS)


def span(msgs):
    t = [ts(x) for m in msgs for x in (m["t0"], m["t1"]) if x]
    return (max(t) - min(t)) if t else 0.0


def subagent_type(tool):
    i = tool.get("input", {})
    return i.get("subagent_type") or ""


def main():
    run = sys.argv[1]
    stream = load(os.path.join(run, "stream.jsonl"))
    init = next(e for e in stream if e.get("type") == "system" and e.get("subtype") == "init")
    result_events = [e for e in stream if e.get("type") == "result"]
    # a turn ends at each background-agent notification; the last result carries the report
    result = result_events[-1] if result_events else {}
    limits = [e["rate_limit_info"] for e in stream if e.get("type") == "rate_limit_event"]
    sid = init["session_id"]
    main_path = glob.glob(os.path.expanduser(f"~/.claude/projects/*/{sid}.jsonl"))[0]
    sub_dir = main_path[:-len(".jsonl")] + "/subagents"

    # main thread, cut into stages
    mmsgs = messages(load(main_path))
    stage, stages = "triage", {"triage": [], "dispatch+merge": [], "synthesis": []}
    for m in mmsgs:
        types = [subagent_type(t) for t in m["tools"] if t.get("name") in ("Agent", "Task")]
        if stage == "triage" and any(x.endswith("-reviewer") for x in types):
            stage = "dispatch+merge"
        if stage == "dispatch+merge" and any(x == "review-pro-verify-subagent" for x in types):
            stage = "synthesis"
        stages[stage].append(m)

    # main thread, cut into turns: each background-agent notification opens a new turn, which
    # re-reads the whole orchestrator context. A waiting turn is a notification turn, not the last,
    # that dispatches nothing: it only acknowledges one result.
    turns, cur, seen = [], None, set()
    for e in load(main_path):
        if e.get("type") == "user":
            c = e["message"]["content"]
            s = c if isinstance(c, str) else " ".join(b.get("text", "") for b in c if b.get("type") == "text")
            if cur is None or "<task-notification>" in s:
                cur = {"notification": cur is not None, "msgs": 0, "tokens": 0, "dispatches": 0}
                turns.append(cur)
        elif e.get("type") == "assistant" and cur is not None and e["message"]["id"] not in seen:
            seen.add(e["message"]["id"])
            cur["msgs"] += 1
            cur["tokens"] += total(e["message"].get("usage") or {})
        if e.get("type") == "assistant" and cur is not None:
            cur["dispatches"] += sum(1 for b in e["message"].get("content", []) if b.get("type") == "tool_use" and b.get("name") in ("Agent", "Task"))
    for i, tn in enumerate(turns):
        tn["waiting"] = tn["notification"] and tn["dispatches"] == 0 and i < len(turns) - 1

    rows = []
    for name, ms in stages.items():
        u = {}
        for m in ms:
            add(u, m["usage"])
        rows.append({"stage": f"main: {name}", "agent": "orchestrator", "n_msgs": len(ms), "usage": u, "wall_s": span(ms)})

    # subagents
    raw_dir = sys.argv[sys.argv.index("--raw") + 1] if "--raw" in sys.argv else None
    tag = sys.argv[sys.argv.index("--tag") + 1] if "--tag" in sys.argv else os.path.basename(run)
    subs = []
    for p in sorted(glob.glob(os.path.join(sub_dir, "agent-*.jsonl"))):
        meta = json.load(open(p[:-len(".jsonl")] + ".meta.json"))
        ev = load(p)
        ms = messages(ev)
        u = {}
        for m in ms:
            add(u, m["usage"])
        a = meta.get("agentType", "?")
        # the task prompt, the reads of files it already carried, and the fixed overhead
        prompt = ""
        for e in ev:
            if e.get("type") == "user":
                c = e["message"]["content"]
                prompt = c if isinstance(c, str) else "".join(b.get("text", "") for b in c if b.get("type") == "text")
                break
        carried = set(re.findall(r"[\w./-]+\.\w+", prompt.split("### Changed file contents", 1)[1])) if "### Changed file contents" in prompt else set()
        results = {}
        for e in ev:
            if e.get("type") == "user" and isinstance(e["message"]["content"], list):
                for b in e["message"]["content"]:
                    if b.get("type") == "tool_result":
                        c = b.get("content")
                        results[b.get("tool_use_id")] = len(c) if isinstance(c, str) else sum(len(x.get("text", "")) for x in (c or []) if isinstance(x, dict))
        reads = [t for m in ms for t in m["tools"] if t.get("name") == "Read"]
        reread = sum(results.get(t["id"], 0) for t in reads
                     if any(t["input"].get("file_path", "").endswith("/" + f) or t["input"].get("file_path", "") == f for f in carried))
        first = ms[0]["usage"] if ms else {}
        first_in = (first.get("input_tokens") or 0) + (first.get("cache_read_input_tokens") or 0) + (first.get("cache_creation_input_tokens") or 0)
        final = ms[-1]["text"] if ms else ""
        if raw_dir and a.endswith("-reviewer"):
            os.makedirs(raw_dir, exist_ok=True)
            with open(os.path.join(raw_dir, f"{tag}-{a}.md"), "w") as fh:
                fh.write(f"<!-- {tag} {a}; verbatim final answer -->\n{final}\n")
        subs.append({"stage": "verify" if a == "review-pro-verify-subagent" else "triage-subagent" if a == "review-pro-triage-subagent"
                     else "synthesis-subagent" if a == "review-pro-synthesize-subagent" else "reviewer",
                     "agent": a, "n_msgs": len(ms), "usage": u, "wall_s": span(ms), "prompt_chars": len(prompt),
                     "first_input": first_in, "reads": len(reads), "reread_chars": reread})
    rows += subs

    # modelUsage per model: the session model's must equal the transcripts. Any other model (Haiku,
    # which summarises WebFetch and WebSearch results) is not in the transcripts; it is its own row.
    mu, aux = {}, {}
    for model, m in (result.get("modelUsage") or {}).items():
        dst = mu if model == init.get("model") else aux
        for a, b in (("inputTokens", "input_tokens"), ("cacheCreationInputTokens", "cache_creation_input_tokens"),
                     ("cacheReadInputTokens", "cache_read_input_tokens"), ("outputTokens", "output_tokens")):
            dst[b] = dst.get(b, 0) + m.get(a, 0)
    opus = {}
    for r in rows:
        add(opus, r["usage"])
    if aux:
        rows.append({"stage": "auxiliary model", "agent": "haiku (web tool summaries)", "n_msgs": 0, "usage": aux, "wall_s": 0.0})
    grand = {}
    for r in rows:
        add(grand, r["usage"])
    start = float(open(os.path.join(run, "start")).read()) if os.path.exists(os.path.join(run, "start")) else None
    end = float(open(os.path.join(run, "end")).read()) if os.path.exists(os.path.join(run, "end")) else None
    summary = {"session": sid, "model": init.get("model"), "cwd": init.get("cwd"), "duration_ms": result.get("duration_ms"),
               "wrapper_s": (end - start) if start and end else None, "num_turns": result.get("num_turns"),
               "cost_usd_list": result.get("total_cost_usd"), "grand": grand, "modelUsage": mu,
               "check": "match" if all(opus.get(k, 0) == mu.get(k, 0) for k in KEYS) else
                        "delta " + " ".join(f"{SHORT[k]}={mu.get(k, 0) - opus.get(k, 0):+d}" for k in KEYS if mu.get(k, 0) != opus.get(k, 0)),
               "n_results": len(result_events), "sum_result_duration_ms": sum(e.get("duration_ms") or 0 for e in result_events),
               "five_hour_util": [l.get("unifiedWindows", {}).get("five_hour", {}).get("utilization") for l in limits],
               "rows": rows, "turns": turns, "result_text": result.get("result", "")}
    json.dump(summary, open(os.path.join(run, "tally.json"), "w"), indent=1)
    with open(os.path.join(run, "report.md"), "w") as fh:
        fh.write(summary["result_text"] or "")

    print(f"session {sid}  model {init.get('model')}  duration {summary['duration_ms']} ms  wrapper {summary['wrapper_s']} s  check {summary['check']}")
    print(f"{'stage':28} {'agent':34} {'msgs':>4} {'in':>6} {'cw':>9} {'cr':>10} {'out':>7} {'total':>10} {'wall_s':>7}")
    for r in rows:
        u = r["usage"]
        print(f"{r['stage']:28} {r['agent']:34} {r['n_msgs']:>4} {u.get('input_tokens',0):>6} {u.get('cache_creation_input_tokens',0):>9} "
              f"{u.get('cache_read_input_tokens',0):>10} {u.get('output_tokens',0):>7} {total(u):>10} {r['wall_s']:>7.0f}")
    print(f"{'TOTAL':63} {'':>4} {grand.get('input_tokens',0):>6} {grand.get('cache_creation_input_tokens',0):>9} "
          f"{grand.get('cache_read_input_tokens',0):>10} {grand.get('output_tokens',0):>7} {total(grand):>10}")
    print("five-hour utilization seen:", summary["five_hour_util"])


if __name__ == "__main__":
    main()
