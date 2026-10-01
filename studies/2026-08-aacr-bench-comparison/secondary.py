"""Secondary endpoints and the H0-guard, from the framework's judge output (registration: Endpoints).

Usage (with the fork's venv, which has the framework's modules):
  <fork>/evaluation/.venv/bin/python secondary.py <fork evaluation dir> <run id> [--out secondary.json]

- Noise rate, as AACR-Bench defines it: unmatched / total generated (`README.md` "Core Metrics";
  `docs/metrics.md` `unmatched_rate`). The framework documents it but does not compute it.
  - A generated comment is matched in a round when some reference's `matched_note` equals it.
  - The generated comments are what the judge saw: the framework's own `load_target_comments`.
  - Per round, summed over instances, averaged over the rounds.
- H0-guard: A2's noise rate minus A1's, against the registered 5-point budget.
- Framework metrics: from metrics_<arm>_average.json, unchanged (semantic precision and recall,
  line precision and recall).
- Recall by category (Code Defect, Maintainability and Readability, Performance, Security
  Vulnerability) and by context. The labels are joined back exactly as in primary.py.
- Cost: wall time and tokens per arm, from the result files.
"""
import collections, glob, json, os, sys

evaldir, run_id = sys.argv[1], sys.argv[2]
sys.path.insert(0, evaldir)
os.environ.setdefault("JUDGE_USE_MOCK", "true")  # import only; no judge call is made here
os.chdir(evaldir)
import config  # noqa: E402
import evaluate  # noqa: E402
from schema import ReviewInstance  # noqa: E402

ARMS = ("claude", "review-pro")
pos = json.load(open("benchmark/AACR-Bench/positive_samples.json"))
by = collections.defaultdict(list)
for pr in pos:
    by[str(pr["target_commit"]).strip()].extend(
        c for c in pr["comments"] if isinstance(c, dict) and c.get("path") and str(c.get("note", "")).strip())
heads = {json.loads(l)["instance_id"]: json.loads(l)["head_commit"] for l in open("data/aacr_bench.jsonl")}


def label(head, ref, key):
    m = [c for c in by[head] if str(c["path"]).strip() == ref["path"] and str(c["note"]).strip() == ref["note"]
         and c.get("from_line") == ref["from_line"] and c.get("to_line") == ref["to_line"]]
    vals = {c[key] for c in m}
    if len(vals) != 1:
        raise SystemExit(f"label join not exact: {ref['path']}:{ref['from_line']}")
    return vals.pop()


out = {"run_id": run_id}
for arm in ARMS:
    results_dir = config.EVALUATION_DIR / "results" / "aacr_bench" / arm / run_id
    rounds = sorted(glob.glob(f"metrics/aacr_bench/{arm}/{run_id}/metrics_{arm}_*_round_*.json"))
    noise_rounds, cat = [], collections.defaultdict(lambda: [0, 0])
    for path in rounds:
        d = json.load(open(path))
        gen_total = unmatched = 0
        for inst in d["eval_res"]:
            iid = inst["instance_id"]
            generated = [c for c in (evaluate.load_target_comments(results_dir, arm, iid) or []) if isinstance(c, dict) and c.get("note")]
            matched = {r.get("matched_note") for r in inst["comments"] if r.get("semantic_match") and r.get("matched_note")}
            gen_total += len(generated)
            unmatched += sum(1 for g in generated if g["note"] not in matched)
            for r in inst["comments"]:
                k = label(heads[iid], r, "category")
                cat[k][0] += 1 if r.get("semantic_match") else 0
                cat[k][1] += 1
        noise_rounds.append(unmatched / gen_total if gen_total else 0.0)
    avg = json.load(open(glob.glob(f"metrics/aacr_bench/{arm}/{run_id}/metrics_{arm}_average.json")[0]))["summary"]
    res = [json.load(open(p)) for p in glob.glob(str(results_dir / "*@*.json"))]
    out[arm] = {
        "noise_rate": sum(noise_rounds) / len(noise_rounds), "noise_rate_rounds": noise_rounds,
        "semantic_precision": avg["semantic_match_rate"], "semantic_recall": avg["semantic_recall_rate"],
        "line_precision": avg["line_match_rate"], "line_recall": avg["line_recall_rate"],
        "generated": avg["generated_notes"], "expected": avg["expected_notes"], "evaluated_instances": avg["evaluated_instances"],
        "recall_by_category": {k: {"refs": t // len(rounds), "recall": m / t} for k, (m, t) in sorted(cat.items())},
        "cost": {"instances": len(res), "review_seconds": sum(r["duration_seconds"] for r in res),
                 "tokens": sum((r.get("token_usage") or {}).get("total_tokens", 0) for r in res)},
    }
diff = out["review-pro"]["noise_rate"] - out["claude"]["noise_rate"]
out["h0_guard"] = {"noise_A2_minus_A1_points": 100 * diff, "budget_points": 5,
                   "verdict": "within budget" if 100 * diff <= 5 else "exceeds budget: report as recall bought with noise"}
text = json.dumps(out, indent=1)
if "--out" in sys.argv:
    open(sys.argv[sys.argv.index("--out") + 1], "w").write(text)
print(text)
