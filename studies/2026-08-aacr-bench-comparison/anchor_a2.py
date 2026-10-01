"""Item 2's anchor classification on A2's raw reviewer answers (Amendment 2 item 9).

Usage: python3 anchor_a2.py <fork evaluation dir> <run id>
Extracts each reviewer subagent's final answer from the preserved transcripts into raw-a2/,
then classifies every finding with studies/2026-09-anchor-spike/measure.py, unchanged, against the
framework's clone cache at the instance's head (base for removed-line quotes). The non-EXACT
rows are then checked by hand, as in item 2. A wrong-line rate above 5% reopens roadmap item 2.
"""
import collections, csv, glob, json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "2026-09-anchor-spike"))
import measure  # noqa: E402

evaldir, run_id = sys.argv[1], sys.argv[2]
inst = {}
for line in open(os.path.join(evaldir, "data/aacr_bench.jsonl")):
    r = json.loads(line)
    inst[r["instance_id"].replace("/", "__")] = r
out_dir = os.path.join(HERE, "raw-a2"); os.makedirs(out_dir, exist_ok=True)
rows = []
for tdir in sorted(glob.glob(os.path.join(evaldir, f"results/aacr_bench/review-pro/{run_id}/transcripts/*"))):
    iid = os.path.basename(tdir); r = inst[iid]
    repo = os.path.join(evaldir, "repo", r["repo"].replace("/", "__"))
    for p in sorted(glob.glob(os.path.join(tdir, "*", "subagents", "agent-*.jsonl"))):
        agent = json.load(open(p[:-len(".jsonl")] + ".meta.json")).get("agentType", "")
        if not agent.endswith("-reviewer"):
            continue
        final = ""
        for l in open(p):
            e = json.loads(l)
            if e.get("type") == "assistant":
                t = "".join(b.get("text", "") for b in e["message"].get("content", []) if b.get("type") == "text")
                if t.strip():
                    final = t
        name = f"{iid}-{agent}-{os.path.basename(p)[6:14]}"
        open(os.path.join(out_dir, name + ".md"), "w").write(f"<!-- {iid} {agent}; verbatim final answer -->\n{final}\n")
        for fd in measure.parse_blocks(final):
            c, d, note = measure.classify(fd, repo, r["head_commit"], r["base_commit"], None)
            rows.append({"instance": iid, "agent": agent, "file": fd["file"], "line": fd["line"], "category": fd.get("category", ""),
                         "class": c, "distance": "" if d is None else d, "note": note})
with open(os.path.join(HERE, "results", "anchor-a2.csv"), "w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
c = collections.Counter(x["class"] for x in rows)
found = c["EXACT"] + c["NEAR"] + c["ELSEWHERE"]
print(f"findings {len(rows)}: " + " ".join(f"{k}={c[k]}" for k in ("EXACT", "NEAR", "ELSEWHERE", "REFS", "BASE", "NOWHERE", "EXEMPT")))
print(f"classifier wrong-line {c['NEAR'] + c['ELSEWHERE']}/{found} (before hand review)")
