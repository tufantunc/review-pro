"""Apply PRE-REGISTRATION.md's decision rules to the tallied cost runs.

Usage: python3 analyze.py <work dir> <case> [<case> ...]     (each <case>/review/tally.json)
Prints per case: total, stage shares, reviewers dispatched, re-read and fixed-overhead shares, and
which stage rules fire; then R-flat and R-cheap across cases.
"""
import json, os, sys

KEYS = ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens", "output_tokens")


def tot(u):
    return sum(u.get(k, 0) for k in KEYS)


def one(work, case):
    t = json.load(open(os.path.join(work, case, "review", "tally.json")))
    rows = t["rows"]
    grand = tot(t["grand"])
    by = {}
    for r in rows:
        key = r["stage"] if r["stage"].startswith("main") or r["stage"] == "auxiliary model" else r["stage"]
        by[key] = by.get(key, 0) + tot(r["usage"])
    revs = [r for r in rows if r["stage"] == "reviewer"]
    rev_tok = sum(tot(r["usage"]) for r in revs)
    rev_inw = sum(r["usage"].get("input_tokens", 0) + r["usage"].get("cache_creation_input_tokens", 0) for r in revs)
    reread = sum(r.get("reread_chars", 0) for r in revs) / 4
    # fixed overhead: the first request's input minus the task prompt, paid again on every turn
    fixed = sum(max(0, r["first_input"] - r["prompt_chars"] / 4) * r["n_msgs"] for r in revs)
    code_revs = [r for r in revs if r["agent"] != "spec-reviewer"]
    out = {
        "case": case, "total": grand, "wall_s": t["wrapper_s"], "turns_main": t["n_results"],
        "shares": {k: v / grand for k, v in sorted(by.items(), key=lambda x: -x[1])},
        "reviewers": len(revs), "code_reviewers": len(code_revs), "verifiers": sum(r["stage"] == "verify" for r in rows),
        "reread_share": reread / rev_inw if rev_inw else 0, "fixed_share": fixed / rev_tok if rev_tok else 0,
        "reviewer_share": rev_tok / grand, "verify_share": by.get("verify", 0) / grand,
        "main_share": sum(v for k, v in by.items() if k.startswith("main")) / grand,
        "waiting_share": sum(x["tokens"] for x in t.get("turns", []) if x["waiting"]) / grand,
        "waiting_turns": sum(1 for x in t.get("turns", []) if x["waiting"]),
        "check": t["check"], "prompt_chars": {r["agent"]: r["prompt_chars"] for r in revs},
    }
    out["fires"] = [name for name, cond in (
        ("S-dispatch", out["reviewer_share"] >= 0.5 and out["reviewers"] >= 4),
        ("S-verify", out["verify_share"] >= 0.25),
        ("S-reread", out["reread_share"] >= 0.2),
        ("S-overhead", out["fixed_share"] >= 0.3)) if cond]
    return out


def main():
    work = sys.argv[1]
    res = {c: one(work, c) for c in sys.argv[2:]}
    for c, o in res.items():
        print(f"== {c}: total {o['total']/1e6:.2f}M  wall {o['wall_s']:.0f}s  main turns {o['turns_main']}  check {o['check']}")
        print("   shares: " + ", ".join(f"{k} {v:.0%}" for k, v in o["shares"].items()))
        print(f"   reviewers {o['reviewers']} (code {o['code_reviewers']}), verifiers {o['verifiers']}; reviewer share {o['reviewer_share']:.0%}, "
              f"main share {o['main_share']:.0%}, verify share {o['verify_share']:.0%}; re-read {o['reread_share']:.0%}, fixed overhead {o['fixed_share']:.0%}")
        print(f"   post hoc: {o['waiting_turns']} waiting turns in the main thread, {o['waiting_share']:.0%} of the total")
        print(f"   stage rules firing: {o['fires'] or 'none'}")
    if {"c77", "c39", "c53"} <= set(res):
        a, b, m = res["c77"]["total"], res["c39"]["total"], res["c53"]["total"]
        print(f"R-flat: c77/c53 = {a/m:.0%} (>= 25%?), c39/c53 = {b/m:.0%} (>= 50%?) -> {'fires' if a/m >= .25 or b/m >= .5 else 'does not fire'}")
        cheap = a <= 0.7e6 and b <= 1.5e6 and not res["c53"]["fires"]
        print(f"R-cheap: c77 {a/1e6:.2f}M <= 0.7M, c39 {b/1e6:.2f}M <= 1.5M, no stage rule on c53 -> {'holds' if cheap else 'does not hold'}")
    json.dump(res, open(os.path.join(work, "analysis.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
