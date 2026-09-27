"""Compare a foreground-dispatch run with its phase A baseline, per PRE-REGISTRATION.md.

Usage: python3 compare.py <work dir> <case> [<case> ...]
Reads <work>/<case>/review/{tally.json,stream.jsonl,report.md} (this study) and
../2026-09-cost-measurement/results/tallies/<case>.json and results/reports/<case>.md (phase A).
Prints waiting turns, totals, wall time, concurrency per agent group, background flags,
equivalence checks E1 to E4, and the decision rule's outcome.
"""
import glob, json, os, re, sys
from datetime import datetime

HERE = os.path.dirname(os.path.abspath(__file__))
PHASE_A = os.path.join(HERE, "..", "2026-09-cost-measurement", "results")
KEYS = ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens", "output_tokens")


def tot(u):
    return sum(u.get(k, 0) for k in KEYS)


def ts(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()


def waiting(t):
    w = [x for x in t.get("turns", []) if x["waiting"]]
    return len(w), sum(x["tokens"] for x in w)


def spans(session):
    main = glob.glob(os.path.expanduser(f"~/.claude/projects/*/{session}.jsonl"))[0]
    out = []
    for p in sorted(glob.glob(main[:-len(".jsonl")] + "/subagents/agent-*.jsonl")):
        a = json.load(open(p[:-len(".jsonl")] + ".meta.json")).get("agentType", "?")
        t = [ts(e["timestamp"]) for e in (json.loads(l) for l in open(p) if l.strip()) if e.get("timestamp")]
        out.append((a, min(t), max(t)))
    return out


def group_stats(sp):
    if not sp:
        return None
    lengths = [e - s for _, s, e in sp]
    events = sorted([(s, 1) for _, s, _ in sp] + [(e, -1) for _, _, e in sp])
    cur = peak = 0
    for _, d in events:
        cur += d
        peak = max(peak, cur)
    merged, union = [], 0.0
    for _, s, e in sorted(sp, key=lambda x: x[1]):
        if merged and s <= merged[-1][1]:
            merged[-1][1] = max(merged[-1][1], e)
        else:
            merged.append([s, e])
    union = sum(e - s for s, e in merged)
    longest, total = max(lengths), sum(lengths)
    verdict = ("parallel" if peak >= 2 and union <= 1.5 * longest else
               "sequential" if union >= 0.8 * total else "mixed") if len(sp) > 1 else "single"
    return {"n": len(sp), "peak": peak, "union_s": union, "longest_s": longest, "sum_s": total, "verdict": verdict}


def background_flags(stream_path):
    flags = []
    for l in open(stream_path):
        e = json.loads(l)
        if e.get("type") == "system" and e.get("subtype") == "task_started":
            flags.append((e.get("subagent_type"), e.get("is_backgrounded")))
    return flags


def equivalence(case, t, report, raw_dir):
    revs = sorted(r["agent"] for r in t["rows"] if r["stage"] == "reviewer")
    a = json.load(open(os.path.join(PHASE_A, "tallies", f"{case}.json")))
    revs_a = sorted(r["agent"] for r in a["rows"] if r["stage"] == "reviewer")
    code = [r for r in revs if r != "spec-reviewer"]
    missing_fe = [r for r in code if "## Files examined" not in open(os.path.join(raw_dir, f"{case}-{r}.md")).read()]
    n_ver = sum(1 for r in t["rows"] if r["stage"] == "verify")
    m = re.search(r"Verification: (\d+) checked", report)
    checked = int(m.group(1)) if m else None
    e4 = {"verdict": bool(re.search(r"^## Verdict", report, re.M)), "spec line": bool(re.search(r"^Spec:", report, re.M)),
          "coverage": "Coverage" in report, "verification": "Verification:" in report,
          "rules": "Repository rules" in report, "spec section": bool(re.search(r"^## Spec", report, re.M))}
    return {"E1 reviewers": revs, "E1 phase A": revs_a, "E1 same set": revs == revs_a,
            "E2 missing Files examined": missing_fe, "E3 verifiers": n_ver, "E3 report checked": checked,
            "E3 ok": checked == n_ver, "E4": e4, "E4 ok": all(e4.values())}


def main():
    work = sys.argv[1]
    verdicts = []
    for case in sys.argv[2:]:
        run = os.path.join(work, case, "review")
        t = json.load(open(os.path.join(run, "tally.json")))
        a = json.load(open(os.path.join(PHASE_A, "tallies", f"{case}.json")))
        report = open(os.path.join(run, "report.md")).read()
        wn, wt = waiting(t)
        wna, wta = waiting(a)
        gt, ga = tot(t["grand"]), tot(a["grand"])
        wall, walla = t["wrapper_s"], a["wrapper_s"]
        sp = spans(t["session"])
        rev = group_stats([x for x in sp if x[0].endswith("-reviewer")])
        ver = group_stats([x for x in sp if x[0] == "review-pro-verify-subagent"])
        eq = equivalence(case, t, report, os.path.join(work, "raw"))
        bg = background_flags(os.path.join(run, "stream.jsonl"))
        print(f"== {case}")
        print(f"   waiting turns: {wn} / {wt/1e3:.0f}K ({wt/gt:.0%})   phase A: {wna} / {wta/1e3:.0f}K ({wta/ga:.0%})")
        print(f"   total: {gt/1e6:.2f}M   phase A: {ga/1e6:.2f}M   ({(gt-ga)/ga:+.0%})")
        print(f"   wall: {wall:.0f} s   phase A: {walla:.0f} s   ({(wall-walla)/walla:+.0%})")
        print(f"   reviewers: {rev}")
        print(f"   verifiers: {ver}")
        print(f"   started in background: {sum(1 for _, b in bg if b)} of {len(bg)}")
        for k, v in eq.items():
            print(f"   {k}: {v}")
        accept = wn <= 1 and wt <= 0.25 * wta and (wall - walla) / walla <= 0.25 and not eq["E2 missing Files examined"] and eq["E3 ok"] and eq["E4 ok"]
        reject = (wall - walla) / walla > 0.5 or bool(eq["E2 missing Files examined"]) or not eq["E3 ok"] or not eq["E4 ok"]
        verdicts.append("accept" if accept else "reject" if reject else "between")
        print(f"   this case: {verdicts[-1]} (E1 set differences are read by hand against the run's own plan)")
    overall = "accept" if all(v == "accept" for v in verdicts) else "reject" if "reject" in verdicts else "between: stop and report"
    print(f"decision: {overall}")


if __name__ == "__main__":
    main()
