"""The registration's endpoints, from the framework's judge output (Amendment 2 item 8).

Usage: python3 primary.py <fork evaluation dir> <run id> [--out results.json]

Inputs, all read-only:
  <eval>/metrics/aacr_bench/<arm>/<run id>/metrics_<arm>_*_round_<n>.json   judge output per round
  <eval>/benchmark/AACR-Bench/positive_samples.json                        the context labels
  <eval>/data/aacr_bench.jsonl                                             the seed-42 sample

Each scored reference in a round's `eval_res[].comments[]` is joined back to its context label.
The join key is the head commit, path and note (both stripped, as the converter does) and
from_line/to_line; the join must be exact, or the script stops.

Primary: per-instance repo-context recall is the repo-labeled references with semantic_match over
the repo-labeled references, averaged over the rounds. The delta is A2 - A1. Instances without a
repo-labeled reference, or not evaluated in both arms, are out of the test. Wilcoxon signed-rank,
two-sided, zero_method "wilcox", exact distribution, alpha 0.05, with the zero-delta count reported.

Descriptive: pooled repo recall per arm (the sum of semantic_match over the repo-labeled references,
averaged over rounds), plus diff and file context recall per arm, reported, never tested.
"""
import collections, glob, json, os, sys

ARMS = ("claude", "review-pro")
CTX = {"Diff Level": "diff", "File Level": "file", "Repo Level": "repo"}


def labels(evaldir):
    pos = json.load(open(os.path.join(evaldir, "benchmark/AACR-Bench/positive_samples.json")))
    by = collections.defaultdict(list)
    for pr in pos:
        by[str(pr["target_commit"]).strip()].extend(
            c for c in pr["comments"] if isinstance(c, dict) and c.get("path") and str(c.get("note", "")).strip())
    heads = {}
    for line in open(os.path.join(evaldir, "data/aacr_bench.jsonl")):
        r = json.loads(line)
        heads[r["instance_id"]] = r["head_commit"]
    return by, heads


def context_of(by, head, ref):
    m = [c for c in by[head] if str(c["path"]).strip() == ref["path"] and str(c["note"]).strip() == ref["note"]
         and c.get("from_line") == ref["from_line"] and c.get("to_line") == ref["to_line"]]
    ctx = {CTX[c["context"]] for c in m}
    if len(ctx) != 1:
        raise SystemExit(f"context join not exact for {head[:8]} {ref['path']}:{ref['from_line']} ({len(m)} matches)")
    return ctx.pop()


def per_instance(evaldir, run_id, arm, by, heads):
    """instance -> context -> list over rounds of (matched, total)."""
    rounds = sorted(glob.glob(os.path.join(evaldir, f"metrics/aacr_bench/{arm}/{run_id}/metrics_{arm}_*_round_*.json")))
    if not rounds:
        raise SystemExit(f"no round files for {arm}/{run_id}")
    out = collections.defaultdict(lambda: collections.defaultdict(list))
    for path in rounds:
        d = json.load(open(path))
        for inst in d["eval_res"]:
            iid = inst["instance_id"]
            counts = collections.defaultdict(lambda: [0, 0])
            for ref in inst["comments"]:
                ctx = context_of(by, heads[iid], ref)
                counts[ctx][1] += 1
                counts[ctx][0] += 1 if ref.get("semantic_match") else 0
            for ctx, (m, t) in counts.items():
                out[iid][ctx].append((m, t))
    return out, len(rounds)


def recall(rounds):
    return sum(m / t for m, t in rounds) / len(rounds)


def main():
    evaldir, run_id = sys.argv[1], sys.argv[2]
    by, heads = labels(evaldir)
    data, nrounds = {}, {}
    for arm in ARMS:
        data[arm], nrounds[arm] = per_instance(evaldir, run_id, arm, by, heads)
    both = sorted(set(data[ARMS[0]]) & set(data[ARMS[1]]))
    rows, deltas = [], []
    for iid in both:
        if "repo" not in data[ARMS[0]][iid]:
            continue
        a1, a2 = recall(data["claude"][iid]["repo"]), recall(data["review-pro"][iid]["repo"])
        rows.append({"instance_id": iid, "repo_refs": data["claude"][iid]["repo"][0][1], "a1": a1, "a2": a2, "delta": a2 - a1})
        deltas.append(a2 - a1)
    result = {"run_id": run_id, "rounds": nrounds, "instances_both_arms": len(both), "primary_rows": rows}
    nonzero = [d for d in deltas if abs(d) > 1e-12]
    result["primary"] = {"n_instances": len(deltas), "n_zero_deltas": len(deltas) - len(nonzero),
                         "mean_delta": (sum(deltas) / len(deltas)) if deltas else None}
    if len(nonzero) >= 1:
        from scipy.stats import wilcoxon
        w = wilcoxon(deltas, zero_method="wilcox", alternative="two-sided", method="exact" if len(nonzero) <= 25 else "auto")
        result["primary"].update(statistic=float(w.statistic), p_value=float(w.pvalue), alpha=0.05)
    for arm in ARMS:
        pooled = {}
        for ctx in ("diff", "file", "repo"):
            per_round = collections.defaultdict(lambda: [0, 0])
            for iid in both:
                for k, (m, t) in enumerate(data[arm][iid].get(ctx, [])):
                    per_round[k][0] += m
                    per_round[k][1] += t
            if per_round:
                pooled[ctx] = {"refs": per_round[0][1], "recall": sum(m / t for m, t in per_round.values()) / len(per_round)}
        result[f"descriptive_{arm}"] = pooled
    text = json.dumps(result, indent=1)
    if "--out" in sys.argv:
        open(sys.argv[sys.argv.index("--out") + 1], "w").write(text)
    print(text)


if __name__ == "__main__":
    main()
