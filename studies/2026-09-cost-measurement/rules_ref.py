"""Reference implementation of review-pro-triage step 8 (repository rules), for the fidelity check.

Usage:
  python3 rules_ref.py <repo> <merge-base> <head> [--rules <path>]   one diff, YAML-ish rows
  python3 rules_ref.py --history <prs.tsv>                            every merged PR, one line per row

Implements the grammar as written in core/skills/review-pro-triage/SKILL.md step 8 at bccb367:
`*` one segment, `**` any number of segments, `{name}` one segment bound across when and then;
a then path counts as changed when it matches a changed file (added ones included); another then
path is dropped when, with `{name}` left open, it matches no file at the merge base; all/any;
states judge > changed-alongside > no-target across bindings; checklist rules are judge; at most
8 judge rows. Unlike studies/2026-09-repo-rules-spike/triggers.py, which measured the draft rules
before this grammar existed, it reads the rules from a rules.md file.
"""
import os, re, subprocess, sys

GIT = "/opt/homebrew/bin/git" if os.path.exists("/opt/homebrew/bin/git") else "/usr/bin/git"
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
REVIEWERS = {"a11y", "ai-antipatterns", "api-contract", "backend", "correctness", "craft", "db", "dry",
             "frontend", "performance", "security", "tests"}


def git(repo, *args):
    return subprocess.run([GIT, "-C", repo, *args], capture_output=True, text=True, check=True).stdout


def rx(glob, bind=None):
    """Glob to regex. `bind` maps {name} to a value; unbound names become named groups (or open)."""
    out, i, seen = "", 0, set()
    while i < len(glob):
        m = re.match(r"\{(\w+)\}", glob[i:])
        if glob.startswith("**", i):
            out += ".*"; i += 2
        elif m:
            n = m.group(1)
            if bind is not None and n in bind:
                out += re.escape(bind[n])
            elif n in seen:
                out += f"(?P={n})"
            else:
                out += f"(?P<{n}>[^/]+)"; seen.add(n)
            i += len(m.group(0))
        elif glob[i] == "*":
            out += "[^/]*"; i += 1
        else:
            out += re.escape(glob[i]); i += 1
    return re.compile("^" + out + "$")


def parse_rules(text):
    rules, cur = [], None
    for n, l in enumerate(text.split("\n"), 1):
        m = re.match(r"^## ([A-Za-z0-9_-]+): \S", l)
        if m:
            cur = {"id": m.group(1), "line": n}
            rules.append(cur)
            continue
        if l.startswith("#"):
            cur = None if l.startswith("## ") else cur
            continue
        f = re.match(r"^- (when|then|owner|rule):\s*(.*)$", l)
        if cur is not None and f:
            cur[f.group(1)] = f.group(2).strip()
    out = []
    for r in rules:
        if "when" not in r or "rule" not in r:
            continue
        when = re.findall(r"`([^`]+)`", r["when"])
        then, mode = [], "all"
        if "then" in r:
            then = re.findall(r"`([^`]+)`", r["then"])
            mm = re.search(r"\((all|any)\)\s*$", r["then"])
            mode = mm.group(1) if mm else "all"
        owner = r.get("owner", "ai-antipatterns")
        out.append({"id": r["id"], "line": r["line"], "when": when, "then": then, "mode": mode,
                    "owner": owner if owner in REVIEWERS else "ai-antipatterns", "text": r["rule"]})
    return out


def evaluate(rules, changed, base_files):
    rows = []
    for r in rules:
        bindings = {}
        for f in changed:
            for w in r["when"]:
                m = rx(w).match(f)
                if m:
                    key = tuple(sorted(m.groupdict().items()))
                    bindings.setdefault(key, set()).add(f)
                    break
        if not bindings:
            continue
        states, matched, missing = [], set(), set()
        for key, files in bindings.items():
            matched |= files
            if not r["then"]:
                states.append("judge"); continue
            bind = dict(key)
            kept, hit = [], {}
            for t in r["then"]:
                concrete = rx(t, bind)
                if any(concrete.match(c) for c in changed):
                    kept.append(t); hit[t] = True; continue
                opened = rx(t)  # {name} left open
                if any(opened.match(b) for b in base_files):
                    kept.append(t); hit[t] = False
            if not kept:
                states.append("no-target"); continue
            label = {t: re.sub(r"\{(\w+)\}", lambda m: bind.get(m.group(1), m.group(0)), t) for t in kept}
            if r["mode"] == "all":
                miss = [label[t] for t in kept if not hit[t]]
                ok = not miss
            else:
                ok = any(hit.values())
                miss = [] if ok else [label[t] for t in kept]
            if ok:
                states.append("changed-alongside")
            else:
                states.append("judge"); missing |= set(miss)
        state = "judge" if "judge" in states else "changed-alongside" if "changed-alongside" in states else "no-target"
        rows.append({"id": r["id"], "line": r["line"], "when_matched": sorted(matched),
                     "then_missing": sorted(missing) if state == "judge" else [], "state": state,
                     "owner": r["owner"], "text": r["text"]})
    judged = [x for x in rows if x["state"] == "judge"]
    dropped = max(0, len(judged) - 8)
    if dropped:
        keep = {id(x) for x in judged[:8]}
        rows = [x for x in rows if x["state"] != "judge" or id(x) in keep]
    return rows, dropped


def one(repo, base, head, rules_text):
    changed = [l for l in git(repo, "diff", "--name-only", f"{base}...{head}").split("\n") if l]
    mb = git(repo, "merge-base", base, head).strip()
    base_files = [l for l in git(repo, "ls-tree", "-r", "--name-only", mb).split("\n") if l]
    return evaluate(parse_rules(rules_text), changed, base_files)


def main():
    if sys.argv[1] == "--history":
        rules_text = open(os.path.join(ROOT, ".review-pro/rules.md")).read()
        rules = parse_rules(rules_text)
        for line in open(sys.argv[2]):
            if not line.strip():
                continue
            num, commit = line.split("\t")[:2]
            changed = [l for l in git(ROOT, "diff", "--name-only", f"{commit}^1", commit).split("\n") if l]
            base_files = [l for l in git(ROOT, "ls-tree", "-r", "--name-only", f"{commit}^1").split("\n") if l]
            rows, dropped = evaluate(rules, changed, base_files)
            for x in rows:
                print(f"#{num}\t{x['id']}\t{x['state']}\tmissing={','.join(x['then_missing'])}\tmatched={len(x['when_matched'])}")
        return
    repo, base, head = sys.argv[1:4]
    rp = sys.argv[sys.argv.index("--rules") + 1] if "--rules" in sys.argv else None
    rules_text = open(rp).read() if rp else git(repo, "show", f"{git(repo, 'merge-base', base, head).strip()}:.review-pro/rules.md")
    rows, dropped = one(repo, base, head, rules_text)
    for x in rows:
        print(f"- id: {x['id']}\n  state: {x['state']}\n  then_missing: {x['then_missing']}\n  when_matched: {x['when_matched']}\n  owner: {x['owner']}")
    print(f"rules_dropped: {dropped}")


if __name__ == "__main__":
    main()
