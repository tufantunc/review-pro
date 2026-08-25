#!/usr/bin/env bash
# scripts/validate.sh — structural validator for review-pro plugin artifacts.
# Usage: ./scripts/validate.sh [ROOT]   (ROOT defaults to repo root)
set -uo pipefail

if [[ $# -ge 1 ]]; then ROOT="$1"; else ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; fi
SKILLS_DIR="$ROOT/core/skills"

ORCHESTRATORS=("review-pro" "review-pro-triage" "review-pro-synthesize")
REQ_FM=("name" "description")
REQ_SECTIONS=(
  "## Role & mandate"
  "## Scope"
  "## What this reviewer flags"
  "## Evidence & severity"
  "## No unresearched findings"
  "## Approval bar"
  "## Output schema"
  "## Cross-reviewer handoff"
  "## Tone"
)

errors=0
add_error(){ echo "FAIL: $*" >&2; errors=$((errors+1)); }

is_orchestrator(){
  local n="$1"
  for o in "${ORCHESTRATORS[@]}"; do [[ "$o" == "$n" ]] && return 0; done
  return 1
}

fm_get(){
  # $1=file $2=key -> echo value (unquoted), empty if absent
  awk -v key="$2" '
    /^---[[:space:]]*$/ { c++; next }
    c==1 && index($0, key":") == 1 {
      val=substr($0, length(key)+2); sub(/^[[:space:]]*/,"",val)
      sub(/^"/,"",val); sub(/"$/,"",val); print val
    }
    c>=2 { exit }
  ' "$1"
}

has_frontmatter(){
  local f="$1"
  [[ -f "$f" ]] || return 1
  [[ "$(head -n1 "$f")" == "---" ]] || return 1
  awk 'NR>1 && /^---[[:space:]]*$/ { found=1; exit } END { exit !found }' "$f"
}

shopt -s nullglob
for skill_md in "$SKILLS_DIR"/*/SKILL.md; do
  name="$(basename "$(dirname "$skill_md")")"
  if ! has_frontmatter "$skill_md"; then
    add_error "$skill_md: missing or malformed frontmatter block"
    continue
  fi
  for k in "${REQ_FM[@]}"; do
    v="$(fm_get "$skill_md" "$k")"
    [[ -n "$v" ]] || add_error "$skill_md: missing frontmatter key '$k'"
  done
  if is_orchestrator "$name"; then
    # Orchestrators have no shared section contract, but each has sections whose
    # silent removal would break the pipeline. Checked per orchestrator.
    # bash 3.2 (macOS default) errors on "${arr[@]}" for an empty array under
    # `set -u`, so drive the loop off a newline-delimited string instead.
    req=""
    case "$name" in
      review-pro-triage)     req=$'## Steps\n## Signal map (non-exhaustive)\n## Dispatch plan format\n## Output discipline' ;;
      review-pro-synthesize) req=$'## Steps\n## Out-of-diff evidence check\n## Spec axis\n## Conflict ownership\n## Output' ;;
    esac
    if [[ -n "$req" ]]; then
      while IFS= read -r h; do
        [[ -n "$h" ]] || continue
        grep -qxF "$h" "$skill_md" || add_error "$skill_md: missing section '$h'"
      done <<< "$req"
    fi
  else
    for h in "${REQ_SECTIONS[@]}"; do
      # -x anchors to a whole line: demoting '## X' to '### X' must fail, not pass.
      grep -qxF "$h" "$skill_md" || add_error "$skill_md: missing section '$h'"
    done
  fi
done
shopt -u nullglob

# Schema-rule parity: reviewer agent bodies embed the output schema inline (see
# docs/internals/reviewer-directive.md) rather than loading core/shared/, and the CLI
# does not install core/shared/ at all. So a rule added to output-schema.md reaches
# reviewers only if the bodies carry it. Guard the seam.
SCHEMA_DOC="$ROOT/core/shared/output-schema.md"
SCHEMA_KEYS=("evidence_refs" "same evidence bar")
if [[ -f "$SCHEMA_DOC" ]]; then
  for key in "${SCHEMA_KEYS[@]}"; do
    grep -qF "$key" "$SCHEMA_DOC" || add_error "core/shared/output-schema.md: expected schema rule mentioning '$key'"
    for body in "$ROOT"/core/agents/*-reviewer.md; do
      grep -qF "$key" "$body" || add_error "$(basename "$body"): inline output schema is missing '$key' (out of sync with core/shared/output-schema.md)"
    done
  done
fi

# Body invariants: the reviewer bodies are one document duplicated per reviewer,
# and the schema-parity keys above cover two tokens of it. These are the structural
# lines whose silent absence changes behaviour. Two of them demonstrably do: a body
# with no nested-subagent bar can fan out inside a parallel review, and one with no
# stack-signals clause ignores pack files the orchestrator injects regardless.
BODY_INVARIANTS=("(review-pro subagent)" "## Identity & mandate" "## Skill discipline (critical)" "## Anti-derailment (critical)" "## Output schema (one block per finding)" "spawn nested subagents" "Stack signals")
for body in "$ROOT"/core/agents/*-reviewer.md; do
  [[ -f "$body" ]] || continue
  for inv in "${BODY_INVARIANTS[@]}"; do
    grep -qF "$inv" "$body" || add_error "$(basename "$body"): body invariant missing: '$inv'"
  done
  grep -qE '## [A-Za-z-]+ findings: none' "$body" \
    || add_error "$(basename "$body"): no '## <Axis> findings: none' sentinel"
done

# Pointer resolution: rubrics reference `shared/<file>.md` relative to the skills
# root's parent. Every referenced target must exist in core/shared/, and the CLI
# must actually install that directory — otherwise the pointers dangle in a real
# install (see issue #25).
SHARED_DIR="$ROOT/core/shared"
for skill_md in "$SKILLS_DIR"/*/SKILL.md; do
  [[ -f "$skill_md" ]] || continue
  while IFS= read -r ref; do
    [[ -n "$ref" ]] || continue
    [[ -f "$SHARED_DIR/${ref#shared/}" ]] || add_error "$skill_md: references '$ref' but core/shared/${ref#shared/} does not exist"
  done < <(grep -oE 'shared/[a-z-]+\.md' "$skill_md" | sort -u)
done
if [[ -f "$ROOT/cli/src/lib/plugin.ts" ]]; then
  grep -qE 'copyShared[^A-Za-z0-9_]*\(' "$ROOT/cli/src/lib/plugin.ts" \
    || add_error "cli/src/lib/plugin.ts: no copyShared — core/shared/ would not reach an install, dangling every 'shared/<file>.md' pointer"
fi

# Load-bearing pipeline rules. Each is a single line in a markdown file whose
# silent deletion disables a feature without failing any other check. The [[ -f ]]
# guards matter: most validator fixtures contain no orchestrator at all, and an
# unguarded check would fire on every one of them.
TRIAGE_MD="$SKILLS_DIR/review-pro-triage/SKILL.md"
if [[ -f "$TRIAGE_MD" ]]; then
  grep -qF 'spec_source' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: no 'spec_source' - the spec axis cannot be dispatched or reported without it"
  grep -qF 'external_premises' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: no 'external_premises' - external premises are never extracted or routed, so no reviewer is ever asked to verify one"
  grep -qF 'Assigning a premise' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: the assign-dispatches rule is gone - a premise can be routed to a reviewer the signal map never dispatches, and nothing reports that it was"
  grep -qF 'does not verify the premise' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: the no-verification prohibition is gone - triage settling premises itself breaks the one-owner rule and produces verifications nobody can attribute"
fi
SYNTH_MD="$SKILLS_DIR/review-pro-synthesize/SKILL.md"
if [[ -f "$SYNTH_MD" ]]; then
  grep -qF 'code-axis findings only' "$SYNTH_MD" \
    || add_error "review-pro-synthesize/SKILL.md: the out-of-diff tripwire is not restricted to the code axis - spec findings would satisfy it on every review and disable the check"
fi
# The scope-creep cap exists in the rubric and in the agent body, and the body is
# the copy that reaches the running subagent. Guard both.
for f in "$SKILLS_DIR/spec/SKILL.md" "$ROOT/core/agents/spec-reviewer.md"; do
  [[ -f "$f" ]] || continue
  grep -qF 'never exceeds Medium' "$f" \
    || add_error "$(basename "$f"): the scope-creep Medium cap is missing - without it scope creep can block"
  grep -qF 'no such hunk' "$f" \
    || add_error "$(basename "$f"): the missing-finding line rule is gone - spec.missing findings would carry an invented line"
  # Both copies, not just the body: review-pro/SKILL.md documents an inline path that
  # applies the rubric instead of the agent body, so an abstain rule present in only
  # one of them leaves that path reporting an unmeasured axis as clean.
  grep -qF 'abstained (no spec text)' "$f" \
    || add_error "$(basename "$f"): the abstain token is gone - an abstain would be indistinguishable from a clean review"
done
# The no-spec defence. Losing the abstain step is how a spec reviewer with an empty
# prompt ends up adopting a document from the diff as the spec.
if [[ -f "$TRIAGE_MD" ]]; then
  grep -qF 'if and only if' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: the conditional-dispatch gate is gone - spec would be dispatched with no spec"
fi
if [[ -f "$ROOT/core/agents/spec-reviewer.md" ]]; then
  grep -qF 'no `### Spec text` section' "$ROOT/core/agents/spec-reviewer.md" \
    || add_error "spec-reviewer.md: the abstain step is gone - the reviewer would review something other than a spec"
  # The preamble above is identical whether step 1 abstains or emits the ordinary
  # none-sentinel, so it cannot detect a regression to the latter. Pin the token that
  # only exists after the fix, in both the body and synthesis's branch for it.
fi
ORCH_MD="$SKILLS_DIR/review-pro/SKILL.md"
if [[ -f "$ORCH_MD" ]]; then
  grep -qF 'quoted requirement' "$ORCH_MD" \
    || add_error "review-pro/SKILL.md: its dedup summary no longer names the spec key - the inline path would use the code key and collapse unattempted requirements"
  grep -qF '### External premises' "$ORCH_MD" \
    || add_error "review-pro/SKILL.md: the '### External premises' prompt section is gone - triage routes premises the orchestrator then never passes to the owning reviewer"
fi
if [[ -f "$SYNTH_MD" ]]; then
  grep -qF 'abstained (no spec text)' "$SYNTH_MD" \
    || add_error "review-pro-synthesize/SKILL.md: no branch for the abstain token - an unmeasured axis would be reported as 'no mismatch'"
  grep -qF 'not on `(file, line)`' "$SYNTH_MD" \
    || add_error "review-pro-synthesize/SKILL.md: the spec pool's dedup rule is gone - unattempted requirements would collapse into one finding"
fi

CTX_POLICY="$SHARED_DIR/context-policy.md"
if [[ -f "$CTX_POLICY" ]]; then
  grep -qF 'which channel settled' "$CTX_POLICY" \
    || add_error "shared/context-policy.md: the settling-channel record is gone - a network answer becomes indistinguishable from a local one and reviews stop being reproducible"
  grep -qF 'locally resolved dependency source' "$CTX_POLICY" \
    || add_error "shared/context-policy.md: the local-first channel is gone - reviewers would reach for the network on a premise the installed dependency already settles, and the answer stops being reproducible"
fi

# Published reviewer count and roster. These are maintained strings in files no
# other check reads: README.md, docs/llms.txt (hand-written, not generated, so the
# site drift check never sees it), and the seven locale dictionaries. The count went
# stale once already because nothing enforced it.
if command -v python3 >/dev/null 2>&1 && [[ -f "$ROOT/manifest.json" ]]; then
  python3 - "$ROOT" <<'PYCHK' || errors=$((errors+1))
import json, sys, glob, os, re
root = sys.argv[1]
# Numeral words per locale, because two site keys spell the count rather than
# writing a digit. Extend this when the count changes or a locale is added; the
# check fails loudly rather than silently when an entry is absent.
NUMERALS = {
    "en": {13: "Thirteen"}, "de": {13: "Dreizehn"}, "fr": {13: "Treize"},
    "nl": {13: "Dertien"}, "tr": {13: "On üç"}, "hi": {13: "तेरह"}, "zh": {13: "十三"},
}
m = json.load(open(os.path.join(root, "manifest.json")))
names = sorted(s["name"] for s in m.get("skills", []) if s.get("role") == "reviewer")
n = len(names)
bad = []

def read(p):
    try: return open(os.path.join(root, p), encoding="utf-8").read()
    except OSError: return None

rd = read("README.md")
if rd is not None:
    if f"**{n} specialist reviewers**" not in rd:
        bad.append(f"README.md: expected '**{n} specialist reviewers**' for the {n} reviewers in manifest.json")
    if f"{n}-reviewer system" not in rd:
        bad.append(f"README.md: expected '{n}-reviewer system' in Acknowledgements")
    for nm in names:
        if f"`{nm}`" not in rd:
            bad.append(f"README.md: reviewer '{nm}' is missing from the enumeration")
    # The README's mermaid diagram names a few reviewers and abbreviates the rest as
    # "...N more". Nothing in that string contains the count, so a grep for the old
    # number cannot find it; it was stale for exactly that reason.
    mm = re.search(r"\u2026(\d+) more", rd)
    if mm:
        named = sum(1 for nm in names if f'["{nm}"]' in rd)
        if named + int(mm.group(1)) != n:
            bad.append(
                f"README.md: the architecture diagram names {named} reviewers and says "
                f"'...{mm.group(1)} more', which totals {named + int(mm.group(1))}, not {n}"
            )
    else:
        bad.append("README.md: the architecture diagram's '...N more' node is gone; the count can no longer be checked")

lt = read("llms.txt") or read(os.path.join("docs", "llms.txt"))
if lt is not None and f"of {n} reviewers" not in lt:
    bad.append(f"docs/llms.txt: expected 'of {n} reviewers'")

# cli/README.md and cli/package.json are PUBLISHED to npm, so a stale count there
# is on the registry page until the next release.
cr = read(os.path.join("cli", "README.md"))
if cr is not None:
    if f"{n} specialist reviewer skills" not in cr:
        bad.append(f"cli/README.md: expected '{n} specialist reviewer skills'")
    if f"## {n} specialist reviewers" not in cr:
        bad.append(f"cli/README.md: expected the heading '## {n} specialist reviewers'")
    for nm in names:
        if f"`{nm}`" not in cr:
            bad.append(f"cli/README.md: reviewer '{nm}' missing from the enumeration")
cp = read(os.path.join("cli", "package.json"))
if cp is not None:
    try:
        desc = json.loads(cp).get("description", "")
    except ValueError:
        desc = ""
    if f"{n} specialist reviewers" not in desc:
        bad.append(f"cli/package.json: description does not state {n} specialist reviewers")


ct = read("CONTRIBUTING.md")
if ct is not None:
    if f"The {n} reviewer rubrics" not in ct:
        bad.append(f"CONTRIBUTING.md: expected 'The {n} reviewer rubrics'")
    # Pinned positively as well as scanned: the neighbourhood scan below goes silent
    # once the count moves more than five, which is exactly the sentence it exists for.
    if f"owned by one of the {n}" not in ct:
        bad.append(f"CONTRIBUTING.md: expected 'owned by one of the {n}' in the add-a-reviewer section")
    # One literal missed a second stale sentence in the same file ("owned by one of
    # the 12"), where no noun follows the number so a lookahead cannot see it. Scope the
    # scan to lines that talk about reviewers instead. A plain band around the count was
    # tried first and rejected: it passed only because this file happens to state no
    # other number between 8 and 18, while a sibling doc already says "16 stack packs",
    # so moving that sentence here would have turned a docs edit into a red build.
    for line in ct.splitlines():
        if not re.search(r"reviewer|rubric|concern", line, re.I):
            continue
        for m in re.finditer(r"\b(\d+)\b", line):
            val = int(m.group(1))
            if val != n and abs(val - n) <= 5:
                bad.append(f"CONTRIBUTING.md: a line about reviewers states '{val}' where the count is {n}")

for f in sorted(glob.glob(os.path.join(root, "docs-src/i18n/*.json"))):
    loc = os.path.basename(f)
    # A trailing comma in one of seven hand-maintained dictionaries is the exact
    # fragility this guard exists for. Without this the raise discarded every finding
    # collected so far and pointed the maintainer at a traceback instead.
    try:
        d = json.load(open(f, encoding="utf-8"))
    except (ValueError, OSError) as exc:
        bad.append(f"docs-src/i18n/{loc}: unreadable ({exc.__class__.__name__}), so its count cannot be checked")
        continue
    p_ = d.get("docs.reviewers.p", "")
    for nm in names:
        if f"<code>{nm}</code>" not in p_:
            bad.append(f"docs-src/i18n/{loc}: reviewer '{nm}' missing from docs.reviewers.p")
    for k in ("cap.c1.title", "docs.toc.reviewers", "docs.reviewers.h2", "docs.overview.p2"):
        v = d.get(k)
        if v is None:
            bad.append(f"docs-src/i18n/{loc}: key '{k}' is missing, so its count cannot be checked")
        elif str(n) not in v:
            bad.append(f"docs-src/i18n/{loc}: '{k}' does not state {n}")
    # The hero H1 and the Stage 2 explainer spell the count as a WORD, so the digit
    # test above structurally cannot see them. They were the largest text on the
    # published page and stayed stale through four review rounds for that reason.
    lang = loc[:-5] if loc.endswith(".json") else loc
    word = NUMERALS.get(lang, {}).get(n)
    for k in ("hero.title", "pipeline.s2.body"):
        v = d.get(k)
        if v is None:
            bad.append(f"docs-src/i18n/{loc}: key '{k}' is missing, so its count cannot be checked")
        elif word is None:
            bad.append(f"docs-src/i18n/{loc}: no numeral word known for {n} in locale '{lang}'; add it to NUMERALS in scripts/validate.sh")
        elif word not in v:
            bad.append(f"docs-src/i18n/{loc}: '{k}' does not spell {n} as '{word}'")

for b in bad:
    print("FAIL: " + b, file=sys.stderr)
sys.exit(1 if bad else 0)
PYCHK
fi
MANIFEST="$ROOT/manifest.json"
AGENTS_DIR="$ROOT/core/agents"

if [[ ! -f "$MANIFEST" ]]; then
  add_error "manifest.json: not found"
else
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import json; json.load(open('$MANIFEST'))" 2>/dev/null || add_error "manifest.json: invalid JSON"
    declared_skills="$(python3 -c "import json;d=json.load(open('$MANIFEST'));print('\n'.join(s['name'] for s in d.get('skills',[])))" 2>/dev/null)"
    # orphan skills: on disk but not declared
    shopt -s nullglob
    for d in "$SKILLS_DIR"/*/; do
      n="$(basename "$d")"
      if ! printf '%s\n' "$declared_skills" | grep -qxF "$n"; then
        add_error "orphan skill '$n' (directory exists but not in manifest)"
      fi
    done
    # declared but absent: the checks above all run disk -> manifest, so deleting a
    # whole skill or agent was invisible while deleting one line inside it was caught.
    # The [[ -f ]] guards on the load-bearing rules below depend on this direction
    # existing, or they pass vacuously for a file that is simply gone.
    while IFS= read -r dn; do
      [[ -n "$dn" ]] || continue
      [[ -f "$SKILLS_DIR/$dn/SKILL.md" ]] \
        || add_error "declared skill '$dn' has no core/skills/$dn/SKILL.md"
    done <<< "$declared_skills"

    # orphan agents: file on disk but not declared. The skills check above runs in
    # one direction only, so a reviewer could be half-registered (skill declared,
    # agent not) and the validator would still print OK. docs/internals/reviewer-directive.md calls
    # this array the source of truth for which agent loads which skill.
    declared_agents="$(python3 -c "import json;d=json.load(open('$MANIFEST'));print('\n'.join(a['name'] for a in d.get('agents',[])))" 2>/dev/null)"
    for af in "$AGENTS_DIR"/*.md; do
      [[ -f "$af" ]] || continue
      an="$(fm_get "$af" "name")"
      [[ -n "$an" ]] || continue
      if ! printf '%s\n' "$declared_agents" | grep -qxF "$an"; then
        add_error "orphan agent '$an' (file exists but not in manifest agents array)"
      fi
    done
    while IFS= read -r da; do
      [[ -n "$da" ]] || continue
      [[ -f "$AGENTS_DIR/$da.md" ]] \
        || add_error "declared agent '$da' has no core/agents/$da.md"
    done <<< "$declared_agents"
    shopt -u nullglob
    # agents reference existing skills
    for a in "$AGENTS_DIR"/*.md; do
      [[ -f "$a" ]] || continue
      ls_skill="$(fm_get "$a" "loads_skill")"
      [[ -n "$ls_skill" ]] || add_error "$(basename "$a"): missing frontmatter key 'loads_skill'"
      if [[ -n "$ls_skill" ]] && [[ ! -f "$SKILLS_DIR/$ls_skill/SKILL.md" ]]; then
        add_error "$(basename "$a"): references missing skill '$ls_skill'"
      fi
      skills_field="$(fm_get "$a" "skills")"
      if [[ -n "$skills_field" ]] && ! echo "$skills_field" | grep -qwF "$ls_skill"; then
        add_error "$(basename "$a"): skills: field must match loads_skill '$ls_skill'"
      fi
    done
  else
    echo "WARN: python3 not found; skipping manifest/reference checks" >&2
  fi
fi

# Stack pack integrity: each pack manifest is valid JSON; every listed reviewer
# has a core skill and a matching pack file.
STACKS_DIR="$ROOT/stacks"
if [[ -d "$STACKS_DIR" ]] && command -v python3 >/dev/null 2>&1; then
  shopt -s nullglob
  for pm in "$STACKS_DIR"/*/manifest.json; do
    pack_dir="$(dirname "$pm")"
    pack_name="$(basename "$pack_dir")"
    python3 -c "import json; json.load(open('$pm'))" 2>/dev/null || add_error "stacks/$pack_name/manifest.json: invalid JSON"
    if ! python3 -c "import json,sys; d=json.load(open(sys.argv[1])); assert isinstance(d.get('reviewers'), list)" "$pm" 2>/dev/null; then
      add_error "stacks/$pack_name/manifest.json: missing 'reviewers' list"
      continue
    fi
    python3 -c "import json,sys; d=json.load(open(sys.argv[1])); assert isinstance(d.get('version'), str) and d['version']" "$pm" 2>/dev/null \
      || add_error "stacks/$pack_name/manifest.json: missing 'version'"
    reviewers="$(python3 -c "import json;d=json.load(open('$pm'));print('\n'.join(d.get('reviewers',[])))" 2>/dev/null)"
    while IFS= read -r r; do
      [[ -n "$r" ]] || continue
      if [[ ! -d "$SKILLS_DIR/$r" ]]; then
        add_error "stacks/$pack_name: lists reviewer '$r' which has no core skill"
      fi
      if [[ ! -f "$pack_dir/$r.md" ]]; then
        add_error "stacks/$pack_name: manifest lists '$r' but $r.md is missing"
      fi
    done <<< "$reviewers"
  done
  shopt -u nullglob
fi

# Guardrail: SKILL.md only under core/skills/ (skip build/deps dirs)
shopt -s nullglob
while IFS= read -r f; do
  case "$f" in
    "$SKILLS_DIR"/*/SKILL.md) ;;
    *) add_error "$f: SKILL.md outside core/skills/";;
  esac
done < <(find "$ROOT" -name SKILL.md -type f \
  -not -path '*/node_modules/*' -not -path '*/.git/*' \
  -not -path '*/cli/plugin/*' -not -path '*/cli/dist/*' 2>/dev/null)

# Guardrail: loads_skill: frontmatter only under core/agents/
while IFS= read -r f; do
  case "$f" in
    "$AGENTS_DIR"/*.md) ;;
    *) if head -n20 "$f" 2>/dev/null | grep -q '^loads_skill:'; then add_error "$f: agent frontmatter outside core/agents/"; fi;;
  esac
done < <(find "$ROOT" -name '*.md' -type f \
  -not -path '*/node_modules/*' -not -path '*/.git/*' \
  -not -path '*/cli/plugin/*' -not -path '*/cli/dist/*' 2>/dev/null)
shopt -u nullglob

# Plugin manifest versions. Four files carry one and none is bumped automatically, so
# they drift silently and a directory listing shows the wrong number until someone
# notices. cli/package.json is the source; the tag check in the publish workflow
# already pins that one to the git tag.
if command -v python3 >/dev/null 2>&1; then
  python3 - "$ROOT" <<'PYVER' || errors=$((errors+1))
import json, os, sys
root = sys.argv[1]
def load(rel):
    p = os.path.join(root, rel)
    return json.load(open(p, encoding="utf-8")) if os.path.exists(p) else None
cli = load("cli/package.json")
if cli is None:
    sys.exit(0)
want = cli["version"]
bad = []
mk = load(".claude-plugin/marketplace.json")
if mk is not None:
    if mk.get("version") != want:
        bad.append(f".claude-plugin/marketplace.json: version {mk.get('version')} != cli {want}")
    for i, pl in enumerate(mk.get("plugins", [])):
        if pl.get("version") != want:
            bad.append(f".claude-plugin/marketplace.json: plugins[{i}].version {pl.get('version')} != cli {want}")
for rel in ("core/.claude-plugin/plugin.json", "core/.codex-plugin/plugin.json"):
    d = load(rel)
    if d is not None and d.get("version") != want:
        bad.append(f"{rel}: version {d.get('version')} != cli {want}")
for b in bad:
    print("FAIL: " + b, file=sys.stderr)
sys.exit(1 if bad else 0)
PYVER
fi

# Category-root registry. Stage 3 dedups on the root, so the registry has to list
# exactly one root per reviewer. It lived only in shared/output-schema.md, which an
# installer that copies just skill directories never delivers, and the `spec` root was
# once missing from it while thirteen reviewers were shipping.
if command -v python3 >/dev/null 2>&1 && [[ -f "$MANIFEST" ]] && [[ -f "$SYNTH_MD" ]]; then
  python3 - "$ROOT" <<'PYROOTS' || errors=$((errors+1))
import json, os, re, sys
root = sys.argv[1]
names = sorted(s["name"] for s in json.load(open(os.path.join(root, "manifest.json")))["skills"]
               if s.get("role") == "reviewer")
bad = []
for rel in ("core/skills/review-pro-synthesize/SKILL.md", "core/shared/output-schema.md"):
    p = os.path.join(root, rel)
    if not os.path.exists(p):
        continue
    text = open(p, encoding="utf-8").read()
    m = re.search(r"^`security`.*$", text, re.M)
    if not m:
        bad.append(f"{rel}: no category-root list found (expected a line starting with `security`)")
        continue
    listed = sorted(re.findall(r"`([a-z][a-z0-9-]*)`", m.group(0)))
    if listed != names:
        missing = [n for n in names if n not in listed]
        extra = [n for n in listed if n not in names]
        detail = []
        if missing: detail.append("missing " + ", ".join(missing))
        if extra: detail.append("not a reviewer: " + ", ".join(extra))
        bad.append(f"{rel}: category roots disagree with manifest.json ({'; '.join(detail)})")
for b in bad:
    print("FAIL: " + b, file=sys.stderr)
sys.exit(1 if bad else 0)
PYROOTS
fi


[[ "$errors" -eq 0 ]] && { echo "OK: all artifacts valid"; exit 0; }
exit 1
