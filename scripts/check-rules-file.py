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
bad, seen, sections, cur, sub = [], {}, [], None, None
for i, l in enumerate(lines, 1):
    if l.startswith("## "):
        cur, sub = {"head": l, "line": i, "body": []}, None
        sections.append(cur)
    elif re.match(r"^#{3,} ", l):
        if cur is None:
            # A '###' before any rule belongs to a placeholder the rule checks below skip.
            cur = {"head": None, "line": i, "body": [], "preamble": True}
            sections.append(cur)
        sub = {"head": l, "line": i, "body": []}
        cur.setdefault("subs", []).append(sub)
    elif sub is not None:
        sub["body"].append(l)
    elif cur is not None:
        cur["body"].append(l)
# A rule field under a '###' heading is ambiguous: triage cannot tell a demoted rule from its
# parent's own fields, so it is one error. Its fields still count for the parent when the parent
# lacks them, so the rest of the report is not a cascade. A '###' with no fields is prose.
field_re = r"^- (when|then|owner|rule):"
for sec in sections:
    for sb in sec.get("subs", []):
        fields = [b for b in sb["body"] if re.match(field_re, b)]
        if fields:
            name = sb["head"].split(":")[0].lstrip("# ")
            bad.append(f"{where}:{sb['line']}: {name} sits under a '###' heading with rule fields; a rule's fields belong directly under its '## <ID>: <title>' heading")
            own = {re.match(field_re, b).group(1) for b in sec["body"] if re.match(field_re, b)}
            sec["body"].extend(b for b in fields if re.match(field_re, b).group(1) not in own)
sections = [sec for sec in sections if not sec.get("preamble")]
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
