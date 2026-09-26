"""Check a repository's .review-pro/rules.md against the format review-pro's triage reads.

Usage: python3 scripts/check-rules-file.py <repo root>
Triage reads the file with no parser (ADR-0011), so a malformed rule is skipped or routed to
nobody without a word. Prints one `FAIL:` line per problem and exits 1 when there is any.
The owner set is the reviewer roster in <repo root>/manifest.json minus `spec`.
"""
import json, os, re, sys

root = sys.argv[1]
where = ".review-pro/rules.md"
reviewers = {s["name"] for s in json.load(open(os.path.join(root, "manifest.json"))).get("skills", [])
             if s.get("role") == "reviewer"} - {"spec"}
lines = open(os.path.join(root, where), encoding="utf-8").read().split("\n")
bad, seen, sections, cur = [], {}, [], None
for i, l in enumerate(lines, 1):
    if re.match(r"^#{3,} [A-Za-z0-9_-]+: \S", l):
        # A demoted heading would fold this rule into the one above it and triage would skip it.
        bad.append(f"{where}:{i}: {l.split(':')[0].lstrip('# ')} sits under a '###' heading; a rule is a '## <ID>: <title>' section")
    if re.match(r"^#{2,} ", l):
        cur = {"head": l, "line": i, "body": []}
        if l.startswith("## "):
            sections.append(cur)
    elif cur is not None:
        cur["body"].append(l)
if not sections:
    bad.append(f"{where}: has no rule sections; triage would read no rules from it")
for sec in sections:
    m = re.match(r"^## ([A-Za-z0-9_-]+): \S", sec["head"])
    if not m:
        bad.append(f"{where}:{sec['line']}: '{sec['head']}' is not a '## <ID>: <title>' heading")
        continue
    rid = m.group(1)
    if rid in seen:
        bad.append(f"{where}:{sec['line']}: rule id '{rid}' appears twice (first at line {seen[rid]})")
    seen.setdefault(rid, sec["line"])
    field, count = {}, {}
    for l in sec["body"]:
        fm = re.match(r"^- (when|then|owner|rule):\s*(.*)$", l)
        if fm:
            count[fm.group(1)] = count.get(fm.group(1), 0) + 1
            field.setdefault(fm.group(1), fm.group(2).strip())
    for k, n in count.items():
        if n > 1:
            bad.append(f"{where}:{sec['line']}: {rid} has more than one '- {k}:' line; triage would read only the first")
    if not re.search(r"`[^`]+`", field.get("when", "")):
        bad.append(f"{where}:{sec['line']}: {rid} has no '- when:' line with a backticked path")
    if not field.get("rule"):
        bad.append(f"{where}:{sec['line']}: {rid} has no '- rule:' line")
    if "then" in field:
        rest = re.sub(r"`[^`]+`\s*,?\s*", "", field["then"]).strip()
        if not re.search(r"`[^`]+`", field["then"]) or rest not in ("", "(all)", "(any)"):
            bad.append(f"{where}:{sec['line']}: {rid}: then mode must be (all) or (any), after backticked paths")
        bound = set(re.findall(r"\{([A-Za-z0-9_]+)\}", field.get("when", "")))
        for name in sorted(set(re.findall(r"\{([A-Za-z0-9_]+)\}", field["then"])) - bound if "when" in field else []):
            bad.append(f"{where}:{sec['line']}: {rid} uses {{{name}}} in then, which when does not bind")
    if "owner" in field and field["owner"] not in reviewers:
        bad.append(f"{where}:{sec['line']}: {rid}: owner '{field['owner']}' is not a code reviewer")
for b in bad:
    print("FAIL: " + b, file=sys.stderr)
sys.exit(1 if bad else 0)
