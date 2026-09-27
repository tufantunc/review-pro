"""Item 2's anchor classification, run on this study's raw reviewer answers.

Usage: python3 anchor.py <work dir> [--csv out.csv]

Reuses studies/2026-09-anchor-spike/measure.py's parse_blocks and classify unchanged. Each raw
file is raw/<case>-<agent>.md; the finding is classified against the case's clone (head = the
case branch, base = main), which cases.py rebuilds with the same shas.
"""
import csv, glob, os, subprocess, sys
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "2026-09-anchor-spike"))
import measure  # noqa: E402

GIT = measure.GIT


def main():
    work = sys.argv[1]
    rows = []
    for f in sorted(glob.glob(os.path.join(HERE, "raw", "*.md"))):
        name = os.path.basename(f)[:-3]
        case = next(c for c in sorted(os.listdir(work), key=len, reverse=True) if name.startswith(c + "-"))
        repo = os.path.join(work, case, "repo")
        head = subprocess.run([GIT, "-C", repo, "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
        base = subprocess.run([GIT, "-C", repo, "rev-parse", "main"], capture_output=True, text=True).stdout.strip()
        for fd in measure.parse_blocks(open(f).read()):
            c, d, note = measure.classify(fd, repo, head, base, None)
            rows.append({"source": name, "file": fd["file"], "line": fd["line"], "category": fd.get("category", ""),
                         "class": c, "distance": "" if d is None else d, "note": note})
    if "--csv" in sys.argv:
        with open(sys.argv[sys.argv.index("--csv") + 1], "w", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=["source", "file", "line", "category", "class", "distance", "note"])
            w.writeheader(); w.writerows(rows)
    c = Counter(r["class"] for r in rows)
    found = c["EXACT"] + c["NEAR"] + c["ELSEWHERE"]
    print(f"n={len(rows)} " + " ".join(f"{k}={c[k]}" for k in ("EXACT", "NEAR", "ELSEWHERE", "REFS", "BASE", "NOWHERE", "EXEMPT")))
    if found:
        print(f"wrong line = {c['NEAR'] + c['ELSEWHERE']}/{found}")
    for r in rows:
        if r["class"] not in ("EXACT", "EXEMPT"):
            print(f"  {r['class']:9} {r['source']:40} {r['file']}:{r['line']} d={r['distance']} {r['note']}")


if __name__ == "__main__":
    main()
