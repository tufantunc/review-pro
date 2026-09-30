"""A2 per-stage wall time and tokens from the preserved transcripts (Amendment 2 item 9).

Usage: python3 stages.py <fork evaluation dir> <run id> [--out stages.json]

Roadmap item 4's method (studies/2026-09-cost-measurement/tally.py, studies/2026-09-foreground-dispatch):
- Main thread: prep + triage runs until the first reviewer dispatch; dispatch, collect and merge
  run until the first verifier dispatch; after that, verification collect and synthesis.
- Subagents are grouped by their agentType. Each group's wall time is the union of its
  members' first-to-last timestamp spans. Concurrency is the peak number of overlapping spans.
- Tokens are counted once per API message id: input, cache write, cache read, output.
A secondary recording only; it is not an endpoint.
"""
import glob, json, os, sys
from datetime import datetime

KEYS = ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens", "output_tokens")


def ts(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()


def load(p):
    return [json.loads(l) for l in open(p) if l.strip()]


def messages(ev):
    seen, out = {}, []
    for e in ev:
        if e.get("type") != "assistant":
            continue
        m = e["message"]
        if m["id"] not in seen:
            seen[m["id"]] = {"usage": {}, "tools": [], "t": []}
            out.append(seen[m["id"]])
        r = seen[m["id"]]
        r["usage"] = m.get("usage") or r["usage"]
        if e.get("timestamp"):
            r["t"].append(ts(e["timestamp"]))
        r["tools"] += [b for b in m.get("content", []) if b.get("type") == "tool_use"]
    return out


def tok(msgs):
    return sum(sum((m["usage"].get(k) or 0) for k in KEYS) for m in msgs)


def union(spans):
    total, cur = 0.0, None
    for s, e in sorted(spans):
        if cur and s <= cur[1]:
            cur[1] = max(cur[1], e)
        else:
            if cur:
                total += cur[1] - cur[0]
            cur = [s, e]
    return total + (cur[1] - cur[0] if cur else 0.0)


def peak(spans):
    ev = sorted([(s, 1) for s, _ in spans] + [(e, -1) for _, e in spans])
    c = p = 0
    for _, d in ev:
        c += d
        p = max(p, c)
    return p


def instance(tdir):
    main = [p for p in glob.glob(os.path.join(tdir, "*.jsonl"))][0]
    mm = messages(load(main))
    stage, st = "triage", {"triage": [], "dispatch+merge": [], "synthesis": []}
    for m in mm:
        types = [t["input"].get("subagent_type", "") for t in m["tools"] if t.get("name") in ("Agent", "Task")]
        if stage == "triage" and any(x.endswith("-reviewer") for x in types):
            stage = "dispatch+merge"
        if stage == "dispatch+merge" and "review-pro-verify-subagent" in types:
            stage = "synthesis"
        st[stage].append(m)
    groups = {"reviewers": [], "verifiers": []}
    sub_tokens = {"reviewers": 0, "verifiers": 0}
    for p in glob.glob(os.path.join(tdir, "*", "subagents", "agent-*.jsonl")):
        a = json.load(open(p[:-len(".jsonl")] + ".meta.json")).get("agentType", "")
        g = "verifiers" if a == "review-pro-verify-subagent" else "reviewers" if a.endswith("-reviewer") else None
        if not g:
            continue
        ev = load(p)
        t = [ts(e["timestamp"]) for e in ev if e.get("timestamp")]
        groups[g].append((min(t), max(t)))
        sub_tokens[g] += tok(messages(ev))
    allt = [x for m in mm for x in m["t"]]
    out = {"wall_s": max(allt) - min(allt) if allt else 0}
    for k, v in st.items():
        t = [x for m in v for x in m["t"]]
        out[f"main_{k}_s"] = (max(t) - min(t)) if t else 0
        out[f"main_{k}_tokens"] = tok(v)
    for g, spans in groups.items():
        out[f"{g}_n"] = len(spans)
        out[f"{g}_union_s"] = union(spans)
        out[f"{g}_peak"] = peak(spans) if spans else 0
        out[f"{g}_longest_s"] = max((e - s for s, e in spans), default=0)
        out[f"{g}_tokens"] = sub_tokens[g]
    return out


def main():
    evaldir, run_id = sys.argv[1], sys.argv[2]
    res = {}
    for tdir in sorted(glob.glob(os.path.join(evaldir, f"results/aacr_bench/review-pro/{run_id}/transcripts/*"))):
        res[os.path.basename(tdir)] = instance(tdir)
    text = json.dumps(res, indent=1)
    if "--out" in sys.argv:
        open(sys.argv[sys.argv.index("--out") + 1], "w").write(text)
    for iid, r in res.items():
        print(f"{iid[:34]:34} wall {r['wall_s']:5.0f}s | triage {r['main_triage_s']:4.0f}s | reviewers {r['reviewers_n']:2} "
              f"union {r['reviewers_union_s']:4.0f}s peak {r['reviewers_peak']} longest {r['reviewers_longest_s']:4.0f}s | "
              f"verifiers {r['verifiers_n']} union {r['verifiers_union_s']:4.0f}s peak {r['verifiers_peak']} | synthesis {r['main_synthesis_s']:4.0f}s")


if __name__ == "__main__":
    main()
