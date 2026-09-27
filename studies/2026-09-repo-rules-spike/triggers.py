"""Part 1 of the repo-rules spike: co-change rule triggers over every merged PR (no model).

Usage: python3 studies/2026-09-repo-rules-spike/triggers.py prs.tsv [--csv out.csv]
prs.tsv: `gh pr list --state merged --base main --limit 200 --json number,title,mergeCommit`
flattened to "number<TAB>merge-commit<TAB>date<TAB>title". Rules mirror rules-draft.md.
"""
import csv, os, re, subprocess, sys

GIT = "/opt/homebrew/bin/git" if os.path.exists("/opt/homebrew/bin/git") else "/usr/bin/git"
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

def rx(glob):
    out, i = "", 0
    while i < len(glob):
        if glob.startswith("**", i):
            out += ".*"; i += 2
        elif glob.startswith("{pack}", i):
            out += "(?P<pack>[^/]+)"; i += 6
        elif glob[i] == "*":
            out += "[^/]*"; i += 1
        else:
            out += re.escape(glob[i]); i += 1
    return re.compile("^" + out + "$")

CORE = ["core/skills/**", "core/agents/**", "core/shared/**"]
SITE_OUT = ["docs/index.html", "docs/docs.html", "docs/*/index.html", "docs/*/docs.html"]
RULES = [
    ("C1", ["docs-src/**"], [], SITE_OUT, "any"),
    ("C2", ["stacks/{pack}/*"], ["stacks/{pack}/manifest.json"], ["stacks/{pack}/manifest.json"], "all"),
    ("C3", ["cli/package.json"], [], ["cli/package-lock.json", ".claude-plugin/marketplace.json",
        "core/.claude-plugin/plugin.json", "core/.codex-plugin/plugin.json", ".cursor-plugin/plugin.json"], "all"),
    ("C4", CORE, [], ["docs/llms.txt"], "all"),
    ("C5", CORE, [], ["cli/README.md"], "all"),
    ("C6", ["manifest.json"], [], ["README.md", "docs/llms.txt", "cli/README.md", "cli/package.json",
        "CONTRIBUTING.md", "docs-src/i18n/*.json"], "all"),
    ("C7", ["core/shared/output-schema.md"], [], ["core/agents/*-reviewer.md"], "any"),
    ("P1", ["core/skills/review-pro-synthesize/SKILL.md"], [], ["core/shared/severity.md"], "all"),
]

def changed(commit):
    r = subprocess.run([GIT, "-C", ROOT, "diff", "--name-only", f"{commit}^", commit], capture_output=True, text=True, check=True)
    return [l for l in r.stdout.split("\n") if l]

def evaluate(rule, files):
    """Returns a list of (binding, status, missing) for each distinct binding the rule matched."""
    rid, when, excl, then, mode = rule
    bindings = {}
    for f in files:
        for w in when:
            m = rx(w).match(f)
            if m:
                b = m.groupdict().get("pack")
                if any(rx(e.replace("{pack}", b) if b else e).match(f) for e in excl):
                    continue
                bindings.setdefault(b, []).append(f)
    out = []
    for b, xs in bindings.items():
        targets = [t.replace("{pack}", b) if b else t for t in then]
        hit = {t: [f for f in files if rx(t).match(f)] for t in targets}
        if mode == "all":
            missing = [t for t, fs in hit.items() if not fs]
        else:
            missing = [] if any(hit.values()) else targets
        out.append((b, "triggered" if missing else "held-by-file", missing, xs))
    return out

def main():
    prs = [l.rstrip("\n").split("\t") for l in open(sys.argv[1]) if l.strip()]
    prs.sort(key=lambda p: int(p[0]))
    rows = []
    for num, commit, date, title in prs:
        files = changed(commit)
        for rule in RULES:
            for b, status, missing, xs in evaluate(rule, files):
                rows.append({"pr": num, "commit": commit, "title": title[:60], "rule": rule[0], "binding": b or "",
                             "status": status, "missing": " ".join(missing), "when_files": " ".join(xs[:4]) + (" ..." if len(xs) > 4 else "")})
    if "--csv" in sys.argv:
        with open(sys.argv[sys.argv.index("--csv") + 1], "w", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
    from collections import Counter
    print(f"PRs: {len(prs)}")
    for rid in [r[0] for r in RULES]:
        c = Counter(r["status"] for r in rows if r["rule"] == rid)
        print(f"{rid}: matched {sum(c.values())}, held-by-file {c['held-by-file']}, triggered {c['triggered']}")
    t = [r for r in rows if r["status"] == "triggered"]
    print(f"total triggered: {len(t)} across {len({r['pr'] for r in t})} PRs")
    for r in t:
        print(f"  #{r['pr']:>3} {r['rule']} {r['binding']:<10} missing: {r['missing']} | {r['title']}")

if __name__ == "__main__":
    main()
