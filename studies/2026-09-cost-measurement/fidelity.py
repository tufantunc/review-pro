"""Triage fidelity: compare triage's repository_rules rows with rules_ref.py on the same clone.

Usage: python3 fidelity.py <work dir> <case>:<run label> [...]

The triage rows come from the run's final answer (report.md, written by tally.py): the YAML
dispatch plan's `repository_rules.rows`. A rule agrees when both sides have a row for it with the
same `state`, the same `owner`, and the same `then_missing`, compared as sets after this
normalisation: an item agrees with a reference path when it is equal to it or, for a glob in the
rule, when it names that glob or a file the glob matches. `when_matched` is compared too and
reported, but is not part of the agreement (PRE-REGISTRATION.md). A row on one side only is a
disagreement.
"""
import os, re, sys
import yaml

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rules_ref


def triage_rows(report):
    blocks = re.findall(r"```(?:ya?ml)?\n(.*?)```", report, re.S) or [report]
    for b in blocks:
        try:
            d = yaml.safe_load(b)
        except Exception:
            continue
        if isinstance(d, dict) and "repository_rules" in d:
            rr = d["repository_rules"] or {}
            return rr.get("rows") or [], d.get("rules_dropped", 0), rr
        if isinstance(d, dict) and "dispatch" in d:
            return [], d.get("rules_dropped", 0), None
    return None, None, None


def covers(item, ref):
    if item == ref:
        return True
    return bool(rules_ref.rx(ref).match(item)) if "*" in ref or "{" in ref else False


def same(a, b):
    a, b = [str(x) for x in (a or [])], [str(x) for x in (b or [])]
    return all(any(covers(x, r) for x in a) for r in b) and all(any(covers(x, r) for r in b) for x in a)


def compare(work, case, label):
    repo = os.path.join(work, case, "repo")
    report = open(os.path.join(work, case, label, "report.md")).read()
    rows, dropped, rr = triage_rows(report)
    ref, ref_dropped = rules_ref.one(repo, "main", "HEAD", rules_ref.git(repo, "show", "main:.review-pro/rules.md"))
    out = []
    if rows is None:
        return [(case, "*", "UNPARSED", "no dispatch plan found in the answer")]
    t = {str(r.get("id")): r for r in rows}
    f = {r["id"]: r for r in ref}
    for rid in sorted(set(t) | set(f)):
        a, b = t.get(rid), f.get(rid)
        if not a or not b:
            out.append((case, rid, "DISAGREE", f"row only in {'triage' if a else 'reference'}: {a or b}"))
            continue
        diffs = []
        if a.get("state") != b["state"]:
            diffs.append(f"state {a.get('state')} vs {b['state']}")
        if (a.get("owner") or "ai-antipatterns") != b["owner"]:
            diffs.append(f"owner {a.get('owner')} vs {b['owner']}")
        if not same(a.get("then_missing"), b["then_missing"]):
            diffs.append(f"then_missing {a.get('then_missing')} vs {b['then_missing']}")
        wm = "when_matched same" if same(a.get("when_matched"), b["when_matched"]) else f"when_matched differs ({len(a.get('when_matched') or [])} vs {len(b['when_matched'])})"
        out.append((case, rid, "AGREE" if not diffs else "DISAGREE", "; ".join(diffs + [wm])))
    if (dropped or 0) != ref_dropped:
        out.append((case, "rules_dropped", "DISAGREE", f"{dropped} vs {ref_dropped}"))
    return out


if __name__ == "__main__":
    work = sys.argv[1]
    allrows = []
    for spec in sys.argv[2:]:
        case, label = spec.split(":")
        allrows += compare(work, case, label)
    for r in allrows:
        print("\t".join(r))
    rules = [r for r in allrows if r[1] not in ("*", "rules_dropped")]
    print(f"agree {sum(r[2] == 'AGREE' for r in rules)}/{len(rules)} rule rows")
