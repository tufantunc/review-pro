"""Anchor spike: search each finding's evidence quote in the repository at the commit read.

Usage: python3 studies/2026-09-anchor-spike/measure.py [--csv out.csv]
Implements PRE-REGISTRATION.md exactly; see that file for the classes and rules.
"""
import csv, glob, os, re, subprocess, sys

GIT = "/opt/homebrew/bin/git" if os.path.exists("/opt/homebrew/bin/git") else "/usr/bin/git"
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OLD = "/private/tmp/claude-501/-Users-tufantunc-Desktop-Projects-Personal-review-pro/95411138-7910-4558-b74e-6fcf6b3a3445/scratchpad/verifier-spike/repos"
NEAR = 5

def git_show(repo, commit, path):
    r = subprocess.run([GIT, "-C", repo, "show", f"{commit}:{path}"], capture_output=True, text=True)
    return r.stdout.split("\n") if r.returncode == 0 else None

def norm(s):
    return re.sub(r"\s+", " ", s.strip())

LABEL = re.compile(r"^[\w./@~-]+\.\w+:\d+(-\d+)?\b\s*")
ANNOT = re.compile(r"^(#|//|--|\*+)\s*[\w./@~-]+(:\d+)?\b")
ELLIPSIS = re.compile(r"\.\.\.|…|\[\.\.\.\]")

def pieces(evidence):
    out = []
    for raw in evidence.split("\n"):
        s = norm(raw)
        if not s or re.fullmatch(r"(\.\.\.|…|\[\.\.\.\])", s):
            continue
        if ANNOT.match(s) and re.search(r"[\w.-]+\.\w+(:\d+)?", s.split()[1] if len(s.split()) > 1 else s):
            # an annotation such as "# validate.sh:230" or "--- cli/src/lib/plugin.ts:11 (not in diff)"
            rest = ANNOT.sub("", s).strip()
            if not rest or rest.startswith("(") or len(rest) < 8:
                continue
        s = LABEL.sub("", s)
        for p in ELLIPSIS.split(s):
            p = p.strip()
            if len(p) >= 8:
                out.append(p)
    return out

def variants(p):
    v = {p}
    if p[:1] in "+-" and len(p) > 1:
        v.add(p[1:].strip())
    return [x for x in v if len(x) >= 8]

def matches(pcs, lines):
    """1-based line numbers where any piece matches."""
    nl = [norm(l) for l in lines]
    hits = set()
    for p in pcs:
        for v in variants(p):
            for i, l in enumerate(nl, 1):
                if l and (l == v or v in l):
                    hits.add(i)
    return hits

def parse_blocks(text):
    lines = text.split("\n")
    starts = [i for i, l in enumerate(lines) if re.match(r"^\s*-\s+severity:", l)]
    blocks = []
    for k, s in enumerate(starts):
        e = starts[k + 1] if k + 1 < len(starts) else len(lines)
        body = lines[s:e]
        ind = len(body[0]) - len(body[0].lstrip()) + 2
        f = {"severity": body[0].split("severity:", 1)[1].strip()}
        i = 1
        while i < len(body):
            l = body[i]
            m = re.match(r"^(\s*)([a-z_]+):\s?(.*)$", l)
            if m and len(m.group(1)) <= ind and m.group(2) in ("category", "file", "line", "title", "evidence", "evidence_refs", "impact", "remedy", "confidence", "overlap_hints"):
                key, val = m.group(2), m.group(3)
                if key == "evidence" and val.strip() in ("|", "|-", ">", ""):
                    j = i + 1; ev = []
                    while j < len(body):
                        lj = body[j]
                        if lj.strip() and (len(lj) - len(lj.lstrip())) <= ind and re.match(r"^\s*[a-z_]+:", lj):
                            break
                        if re.match(r"^\s*-\s+severity:", lj) or lj.startswith("## "):
                            break
                        ev.append(lj); j += 1
                    f["evidence"] = "\n".join(ev); i = j; continue
                f[key] = val.strip()
                if key == "evidence":
                    f["evidence"] = val.strip()
                if key in ("impact",) and val.strip() == "|":
                    f[key] = ""
            elif l.startswith("## ") or l.startswith("```") and "file" in f and "evidence" in f:
                break
            i += 1
        if "file" in f and "line" in f:
            blocks.append(f)
    return blocks

def ref_paths(refs):
    out = []
    for r in re.findall(r"[\w./@~-]+", (refs or "").strip("[]")):
        p = re.sub(r":\d+(-\d+)?$", "", r)
        if "/" in p or "." in p:
            out.append(p)
    return out

def removed_lines(patch_path, path):
    if not patch_path or not os.path.exists(patch_path):
        return []
    out, cur = [], None
    for l in open(patch_path, errors="replace"):
        if l.startswith("diff --git"):
            cur = l.strip().split(" b/")[-1]
        elif cur == path and l.startswith("-") and not l.startswith("---"):
            out.append(l[1:].rstrip("\n"))
    return out

def sources():
    S = []
    for n in ("correctness", "craft", "tests"):
        S.append((f"studies/2026-09-coverage-spike/raw/{n}.md", ROOT, "8649dad", "c33da43", None, "real"))
    for f in sorted(glob.glob(os.path.join(ROOT, "studies/2026-09-refuting-verifier/acceptance/e2e/raw/A-*.md"))):
        if "verify" in f:
            continue
        S.append((os.path.relpath(f, ROOT), f"{OLD}/aspire", "8eeb25bd", "5552e243", f"{OLD}/aspire.diff.patch", "real"))
    S.append(("studies/2026-09-refuting-verifier/acceptance/e2e/raw/B-security.md", f"{OLD}/probe-p4-control", "7e99a37", "7e99a37~1", None, "real"))
    for f in sorted(glob.glob(os.path.join(ROOT, "studies/2026-09-refuting-verifier/items/V*.md")) +
                    glob.glob(os.path.join(ROOT, "studies/2026-09-refuting-verifier/acceptance/run2/items/W*.md"))):
        t = open(f).read()
        repo = re.search(r"^Checkout[^:]*:\s*(\S+)", t, re.M).group(1)
        patch = (re.search(r"^Diff under review:\s*(\S+)", t, re.M) or [None, None])[1]
        head = subprocess.run([GIT, "-C", repo, "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
        S.append((os.path.relpath(f, ROOT), repo, head, None, patch, "curated"))
    for f in sorted(glob.glob(os.path.join(ROOT, "studies/2026-09-anchor-spike/raw/dogfood-*.md"))):
        commit = re.search(r"commit read: (\w+)", open(f).read()).group(1)
        S.append((os.path.relpath(f, ROOT), ROOT, commit, "a1a5ab6", None, "real"))
    return S

def classify(fd, repo, head, base, patch):
    cat = fd.get("category", "")
    try:
        line = int(re.match(r"\d+", fd["line"]).group(0))
    except Exception:
        line = 0
    if cat.startswith("spec.") or line == 0:
        return "EXEMPT", None, ""
    pcs = pieces(fd.get("evidence", ""))
    if not pcs:
        return "NOWHERE", None, "no usable piece"
    path = fd["file"]
    content = git_show(repo, head, path)
    if content is not None:
        hits = matches(pcs, content)
        if line in hits:
            return "EXACT", 0, ""
        if hits:
            d = min(abs(h - line) for h in hits)
            return ("NEAR" if d <= NEAR else "ELSEWHERE"), d, f"nearest match line {min(hits, key=lambda h: abs(h-line))}"
    for rp in ref_paths(fd.get("evidence_refs")):
        rc = git_show(repo, head, rp)
        if rc and matches(pcs, rc):
            return "REFS", None, rp
    if base:
        bc = git_show(repo, base, path)
        if bc and matches(pcs, bc):
            return "BASE", None, f"{base}:{path}"
    rl = removed_lines(patch, path)
    if rl and matches(pcs, rl):
        return "BASE", None, "diff removed lines"
    return "NOWHERE", None, "file missing at head" if content is None else ""

def main():
    rows = []
    for src, repo, head, base, patch, kind in sources():
        for fd in parse_blocks(open(os.path.join(ROOT, src)).read()):
            c, d, note = classify(fd, repo, head, base, patch)
            rows.append({"source": src, "kind": kind, "file": fd["file"], "line": fd["line"],
                         "category": fd.get("category", ""), "title": fd.get("title", "")[:70],
                         "class": c, "distance": "" if d is None else d, "note": note})
    if "--csv" in sys.argv:
        with open(sys.argv[sys.argv.index("--csv") + 1], "w", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
    from collections import Counter
    for label, sel in (("all", rows), ("real", [r for r in rows if r["kind"] == "real"])):
        c = Counter(r["class"] for r in sel)
        found = c["EXACT"] + c["NEAR"] + c["ELSEWHERE"]
        nonex = len(sel) - c["EXEMPT"]
        print(f"[{label}] n={len(sel)} " + " ".join(f"{k}={c[k]}" for k in ("EXACT","NEAR","ELSEWHERE","REFS","BASE","NOWHERE","EXEMPT")))
        if found:
            print(f"  wrong line = {c['NEAR']+c['ELSEWHERE']}/{found} = {100*(c['NEAR']+c['ELSEWHERE'])/found:.1f}%   breaks dedup = {c['ELSEWHERE']}/{found} = {100*c['ELSEWHERE']/found:.1f}%")
        if nonex:
            u = c["REFS"] + c["BASE"] + c["NOWHERE"]
            print(f"  unanchorable = {u}/{nonex} = {100*u/nonex:.1f}%")
    for r in rows:
        if r["class"] not in ("EXACT", "EXEMPT"):
            print(f"  {r['class']:9} {r['source'].split('/')[-1]:30} {r['file']}:{r['line']} d={r['distance']} {r['note']} | {r['title']}")

if __name__ == "__main__":
    main()
