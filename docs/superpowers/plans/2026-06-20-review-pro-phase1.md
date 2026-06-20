# Review-Pro Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a structurally-valid, installable, end-to-end-demoable slice of review-pro: foundation + validation harness + shared docs + 2 reviewer skills (`security`, `craft`) + 2 orchestrator skills (`triage`, `synthesize`) + subagents + the opencode adapter.

**Architecture:** Tiered review pipeline (triage → fan-out → synthesis). Cross-platform agnostic core (`/core`) of markdown skills/agents + shared docs; a bash validation harness gives us real, runnable verification (TDD) for a prompt/markdown project. opencode adapter is a thin install shim.

**Tech Stack:** Markdown skills/agents (the core asset), Bash (validation harness + install), JSON (manifest + config), YAML frontmatter.

**Verification model:** This is a prompt/markdown project, so "tests" = (1) a TDD'd bash validator that checks structural integrity (frontmatter, required sections, manifest/reference consistency), (2) an install smoke test, and (3) a manual end-to-end review checkpoint at the end.

**Phasing note:** The spec's v0.1 MVP (`docs/superpowers/specs/2026-06-20-review-pro-design.md` §12) is delivered across three plan-phases: **Phase 1** (this plan — foundation + 2 reviewers + orchestrators + opencode adapter), **Phase 2** (remaining 10 reviewers), **Phase 3** (stack packs). Phase 1 is split out because the 12 reviewer skills are independent units and the foundational slice must exist first.

---

## File map (locked decomposition)

| File | Responsibility |
|---|---|
| `LICENSE` | MIT license |
| `.gitignore` | ignore opencode install targets, temp |
| `manifest.json` | plugin manifest: skills (role) + agents (loads_skill) |
| `review-pro.config.example` | sample per-repo config |
| `core/shared/severity.md` | severity levels + verdict rules |
| `core/shared/output-schema.md` | finding block schema + category conventions |
| `core/shared/context-policy.md` | per-reviewer scoped-context rules |
| `core/shared/glossary.md` | shared terms |
| `core/skills/security/SKILL.md` | security reviewer rubric |
| `core/skills/craft/SKILL.md` | maintainability reviewer rubric |
| `core/skills/review-pro-triage/SKILL.md` | Stage 1 orchestrator |
| `core/skills/review-pro-synthesize/SKILL.md` | Stage 3 orchestrator |
| `core/agents/security-reviewer.md` | security subagent role def |
| `core/agents/craft-reviewer.md` | craft subagent role def |
| `core/agents/review-pro-triage-subagent.md` | triage subagent role def |
| `core/agents/review-pro-synthesize-subagent.md` | synthesize subagent role def |
| `scripts/validate.sh` | structural validator (TDD'd) |
| `scripts/validate.test.sh` | tests for the validator |
| `adapters/opencode/install.sh` | install shim for opencode |
| `adapters/opencode/README.md` | opencode adapter docs |
| `README.md` | project overview + install + usage |

**Reviewer-skill section contract** (the validator enforces these 9 headers on every reviewer skill; orchestrator skills only need frontmatter):
`## Role & mandate`, `## Scope`, `## What this reviewer flags`, `## Evidence & severity`, `## No unresearched findings`, `## Approval bar`, `## Output schema`, `## Cross-reviewer handoff`, `## Tone`.

---

## Task 1: Repo scaffolding

**Files:**
- Create: `LICENSE`
- Create: `.gitignore`

- [ ] **Step 1: Create `.gitignore`**

```
# opencode install targets (never commit local config copies)
.opencode-copy/
.tmp/
*.log
```

- [ ] **Step 2: Create `LICENSE` (MIT)**

```
MIT License

Copyright (c) 2026 review-pro contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 3: Commit**

```bash
git add LICENSE .gitignore
git commit -m "chore: add license and gitignore"
```

---

## Task 2: Validation harness v1 (TDD — frontmatter + reviewer sections)

**Files:**
- Create: `scripts/validate.sh`
- Create: `scripts/validate.test.sh`

- [ ] **Step 1: Write the failing test**

Create `scripts/validate.test.sh`:

```bash
#!/usr/bin/env bash
# Tests for scripts/validate.sh. Run: bash scripts/validate.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="$HERE/validate.sh"
pass=0; fail=0
ok(){ echo "ok - $1"; pass=$((pass+1)); }
bad(){ echo "not ok - $1"; fail=$((fail+1)); }

write_good_reviewer(){ cat > "$1" <<'EOF'
---
name: security
description: "security reviewer"
---
# Security Reviewer
## Role & mandate
r
## Scope
s
## What this reviewer flags
f
## Evidence & severity
e
## No unresearched findings
n
## Approval bar
a
## Output schema
o
## Cross-reviewer handoff
c
## Tone
t
EOF
}

write_orchestrator(){ cat > "$1" <<'EOF'
---
name: review-pro-triage
description: "triage"
---
# Triage
EOF
}

# Case A: clean tree -> exit 0
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/review-pro-triage" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_orchestrator "$T/core/skills/review-pro-triage/SKILL.md"
if bash "$VALIDATE" "$T" >/dev/null 2>&1; then ok "clean tree passes"; else bad "clean tree should pass"; fi
rm -rf "$T"

# Case B: reviewer missing a required section -> fail, mentions section
T=$(mktemp -d)
mkdir -p "$T/core/skills/security"
write_good_reviewer "$T/core/skills/security/SKILL.md"
printf '' > "$T/core/skills/security/SKILL.md.tmp"
grep -v '^## Tone$' "$T/core/skills/security/SKILL.md" > "$T/core/skills/security/SKILL.md.tmp"
mv "$T/core/skills/security/SKILL.md.tmp" "$T/core/skills/security/SKILL.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "missing section '## Tone'"; then ok "missing section detected"; else bad "missing section not detected"; fi
rm -rf "$T"

# Case C: skill missing frontmatter name -> fail
T=$(mktemp -d)
mkdir -p "$T/core/skills/security"
cat > "$T/core/skills/security/SKILL.md" <<'EOF'
---
description: "no name"
---
# x
## Role & mandate
r
## Scope
s
## What this reviewer flags
f
## Evidence & severity
e
## No unresearched findings
n
## Approval bar
a
## Output schema
o
## Cross-reviewer handoff
c
## Tone
t
EOF
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "missing frontmatter key 'name'"; then ok "missing name detected"; else bad "missing name not detected"; fi
rm -rf "$T"

echo "---"
echo "pass=$pass fail=$fail"
[[ "$fail" -eq 0 ]]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash scripts/validate.test.sh`
Expected: FAIL — `validate.sh` does not exist yet (all cases error).

- [ ] **Step 3: Implement `validate.sh` (v1)**

Create `scripts/validate.sh`:

```bash
#!/usr/bin/env bash
# scripts/validate.sh — structural validator for review-pro plugin artifacts.
# Usage: ./scripts/validate.sh [ROOT]   (ROOT defaults to repo root)
set -uo pipefail

if [[ $# -ge 1 ]]; then ROOT="$1"; else ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; fi
SKILLS_DIR="$ROOT/core/skills"

ORCHESTRATORS=("review-pro-triage" "review-pro-synthesize")
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
  awk -v key="$key" '
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
  if ! is_orchestrator "$name"; then
    for h in "${REQ_SECTIONS[@]}"; do
      grep -qF "$h" "$skill_md" || add_error "$skill_md: missing section '$h'"
    done
  fi
done
shopt -u nullglob

[[ "$errors" -eq 0 ]] && { echo "OK: all artifacts valid"; exit 0; }
exit 1
```

Make it executable: `chmod +x scripts/validate.sh scripts/validate.test.sh`

- [ ] **Step 4: Run test to verify it passes**

Run: `bash scripts/validate.test.sh`
Expected: `pass=3 fail=0`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/validate.sh scripts/validate.test.sh
git commit -m "test: add structural validator (frontmatter + reviewer sections)"
```

---

## Task 3: Shared docs

**Files:**
- Create: `core/shared/severity.md`
- Create: `core/shared/output-schema.md`
- Create: `core/shared/context-policy.md`
- Create: `core/shared/glossary.md`

- [ ] **Step 1: Create `core/shared/severity.md`**

```markdown
# Severity & Verdict (shared)

Every reviewer and the synthesizer use the same severity scale and verdict rules.

## Severity levels

| Level | Definition |
|---|---|
| Critical | Exploitable / data loss / broken core functionality in the diff |
| High | Likely bug or security issue with concrete impact in changed code |
| Medium | Real correctness/quality risk, scoped or conditional |
| Low | Minor risk or quality nit worth fixing |
| Nitpick | Style/preference, optional |

## Verdict (synthesizer)

| Verdict | Condition |
|---|---|
| BLOCK | any unaddressed Critical or High finding |
| REQUEST CHANGES | any Medium-or-above finding |
| APPROVE | only Low/Nitpick, or no findings |

The synthesizer may downgrade severity only when evidence is incomplete; it never upgrades beyond what a specialist justified.
```

- [ ] **Step 2: Create `core/shared/output-schema.md`**

```markdown
# Finding output schema (shared)

Every specialist returns zero or more finding blocks in this exact shape so the synthesizer can dedup and weight them.

```
- severity: High                 # Critical | High | Medium | Low | Nitpick
  category: security.authz       # <domain>.<subdomain>
  file: src/api/orders.ts
  line: 42
  title: missing ownership check on order update
  evidence: |
    <minimal code excerpt proving the issue>
  impact: <concrete, traced impact>
  remedy: <actionable fix>
  confidence: high               # high | medium | low
  overlap_hints: [backend.authz, correctness.logic]   # for synthesis dedup
```

## Category roots (use these as the `<domain>` prefix)

`security`, `correctness`, `craft`, `ai-antipatterns`, `dry`, `performance`, `backend`, `frontend`, `a11y`, `db`, `api-contract`, `tests`.

Rules:
- `file` + `line` are mandatory for every finding.
- `evidence` must be a real excerpt, not a paraphrase.
- `overlap_hints` lists other category roots that might flag the same spot — this is what the synthesizer uses to collapse duplicates.
```

- [ ] **Step 3: Create `core/shared/context-policy.md`**

```markdown
# Context-gathering policy (shared)

Baseline for every reviewer: the **diff** + **full contents of changed files**.

Triage adds scoped extra context per reviewer so each subagent gets what it needs instead of the whole repo:

| Reviewer | Extra scoped context |
|---|---|
| security | callers/callees of changed security-relevant code; related tests |
| correctness | consumers of changed functions; related error paths |
| craft / ai-antipatterns | neighboring module code; existing conventions & helpers (repo search) |
| dry | repo-wide symbol & pattern search for duplicates / existing helpers |
| db | migration history; schema definitions |
| api-contract | consumers of changed APIs (frontend calls, other services) |
| tests | the production code under test |
| performance | query definitions; hot-path / render files |
| frontend / a11y | design-system tokens; shared UI primitives |

Principle: scoped, not whole-repo. Only `dry`, `craft`, and `ai-antipatterns` ever do repo-wide search, and only for symbols/patterns relevant to the diff.
```

- [ ] **Step 4: Create `core/shared/glossary.md`**

```markdown
# Glossary (shared)

- **triage** — Stage 1: classify files, detect relevant reviewers + active stacks, scope context, emit a dispatch plan. Does not review code.
- **fan-out** — Stage 2: only the triage-selected specialists run in parallel, each with its scoped context and composed rubric.
- **synthesis** — Stage 3: dedup, weight, resolve conflicts, calibrate severity, produce verdict + report.
- **reviewer** — a specialist subagent that owns one concern and returns structured findings.
- **dispatch plan** — triage's YAML output: active stacks + per-reviewer scoped context.
- **scoped context** — the exact files/search results a reviewer receives (diff + changed files + reviewer-specific extras).
- **effective rubric** — what a reviewer actually uses = core skill + active stack packs, composed by the orchestrator.
- **stack pack** — a per-language/framework supplement that adds concrete signals/remedies to a core reviewer rubric.
- **overlap_hints** — category roots attached to a finding so synthesis can collapse duplicates.
- **base** — the diff base branch (default `main`), configurable via `review-pro.config`.
```

- [ ] **Step 5: Commit**

```bash
git add core/shared/
git commit -m "docs: add shared severity, output-schema, context-policy, glossary"
```

---

## Task 4: Reviewer skills — security + craft

**Files:**
- Create: `core/skills/security/SKILL.md`
- Create: `core/skills/craft/SKILL.md`

- [ ] **Step 1: Create `core/skills/security/SKILL.md`**

````markdown
---
name: security
description: "Security audit of changed code: authn/authz bypass, secret/PII leaks, injection, unsafe deserialization, weak crypto, CSRF/SSRF/open redirect, feature-gate leaks. Use for security review, authz check, secret leak, injection or deserialization audit of a diff."
version: 0.1.0
---

# Security Reviewer

## Role & mandate
You are a security reviewer. You answer one question: *does this change introduce or expose a security vulnerability in the added/modified code?*

## Scope
- Review ONLY added/modified code in the diff. Do not report pre-existing issues in untouched code.
- Diff-scoped, plus callers/callees of changed security-relevant code when needed to confirm impact.
- Out of scope: maintainability (craft), performance, accessibility.

## What this reviewer flags
- **Authn/authz:** missing ownership/permission checks on protected resources; privilege escalation; IDOR; broken session handling.
- **Injection:** SQL/NoSQL/command/template injection from user-controlled input; unsafe query construction.
- **Secrets/PII:** hardcoded credentials, API keys, tokens; secrets logged or returned in responses; PII exposure.
- **Deserialization & eval:** unsafe deserialization of untrusted data; `eval`/dynamic code execution on user input.
- **Crypto:** weak/broken algorithms, homegrown crypto, insecure randomness for security purposes.
- **CSRF / SSRF / open redirect** introduced by the change.
- **Feature-gate / secret leaks** that should stay gated.

## Evidence & severity
Every finding needs `file:line` + a code excerpt + a concrete attack/impact path.
- **Critical:** directly exploitable in the diff (auth bypass, RCE, data exposure).
- **High:** likely exploitable under realistic conditions.
- **Medium:** requires specific conditions or has limited blast radius.
- **Low:** defense-in-depth gap / hardening opportunity.
- **Nitpick:** minor.
- Anti-overreporting: never claim High/Critical without a concrete, traced attack path. If you cannot trace it end-to-end, downgrade or drop it.

## No unresearched findings
Never present an issue with unfinished research. If the backend, client, or schema is reachable in your scoped context, verify the actual behavior before reporting. "Maybe X handles it" is forbidden when you can check.

## Approval bar
Block when any Critical/High security finding is present and unaddressed. Otherwise list concrete remediations. Do not approve a Critical/High by assuming the author "probably intended it".

## Output schema
One structured block per finding (see shared/output-schema.md). Use category roots like `security.authz`, `security.injection`, `security.secrets`.

```
- severity: High
  category: security.authz
  file: src/api/orders.ts
  line: 42
  title: missing ownership check on order update
  evidence: |
    app.put('/orders/:id', (req, res) => updateOrder(req.params.id, req.body))
  impact: any authenticated user can update another user's order
  remedy: authorize(ctx.userId === order.userId) before update
  confidence: high
  overlap_hints: [backend.authz, correctness.logic]
```

## Cross-reviewer handoff
- Auth/validation findings also surfaced by `backend-reviewer`: you own the severity; it owns the structural remedy.
- A logic bug that is also security-relevant: you own severity when the impact crosses a security boundary.

## Tone
Direct, high-conviction, no hedging. Skip cosmetic nits when real vulnerabilities exist. Never soften a Critical into a polite suggestion.
````

- [ ] **Step 2: Create `core/skills/craft/SKILL.md`**

````markdown
---
name: craft
description: "Strict maintainability audit: code-judo, the 1k-line rule, spaghetti growth, abstraction/boundary quality, layer leaks, type-boundary cleanliness, canonical-helper reuse. Use for code quality review, refactor, maintainability or code-judo audit of a diff."
version: 0.1.0
---

# Craft Reviewer

## Role & mandate
You are a maintainability reviewer. You answer one question: *does this change make the codebase structurally cleaner, or messier — and is there a dramatically simpler reframe?*

## Scope
- Added/modified code in the diff, plus neighboring modules needed to judge structure.
- Repo-wide duplicate detection is the `dry-reviewer`'s job; you flag duplication only when it affects local structure.
- Out of scope: security, correctness bugs, performance numbers.

## What this reviewer flags
- **Code-judo opportunities:** reorganizations that delete whole branches/helpers/modes while preserving behavior. The highest-value finding type — search aggressively for it.
- **1k-line rule:** a file this change pushes from under ~1000 lines to over ~1000 lines without strong justification. Flag for decomposition.
- **Spaghetti growth:** ad-hoc conditionals, special cases, one-off flags bolted into unrelated flows.
- **Abstraction quality:** thin identity wrappers, pass-through helpers, premature/needless abstractions that add indirection without clarity.
- **Boundary/layer leaks:** feature logic in shared paths; implementation details leaking through APIs; logic in the wrong package.
- **Type-boundary cleanliness:** unnecessary `any`/casts/optionality that obscure the real invariant.
- **Canonical-helper reuse:** bespoke helpers where a canonical utility already exists.

## Evidence & severity
Every finding needs `file:line` + excerpt + why it is a structural regression + the concrete simpler alternative.
- **Critical:** the change makes a core module materially harder to reason about, or misses an obvious code-judo move that would delete a large chunk of complexity.
- **High:** clear structural regression (file crosses 1k via this PR; new spaghetti in a busy flow).
- **Medium:** missed simplification or modest layer leak.
- **Low:** minor cleanup.
- **Nitpick:** naming/formatting.
- Anti-overreporting: do not flood with Low/Nitpick when structural issues exist.

## No unresearched findings
Before claiming "a canonical helper already exists", verify it in your scoped context. Before claiming a refactor preserves behavior, confirm against the diff and related code.

## Approval bar
Do not approve if: a clear structural regression; an obvious missed code-judo simplification; unjustified file-size explosion past 1k; or ad-hoc branching that tangles an existing flow. "It works" is not sufficient.

## Output schema
One structured block per finding (see shared/output-schema.md). Use category roots like `craft.spaghetti`, `craft.size`, `craft.boundary`, `craft.abstraction`.

```
- severity: High
  category: craft.size
  file: src/services/orders.ts
  line: 1
  title: file crosses 1000 lines in this PR
  evidence: |
    +412 lines -> 1187 total
  impact: orders.ts becomes the repo's largest file and a change magnet
  remedy: extract OrderValidator and OrderPricing into modules first
  confidence: high
  overlap_hints: [dry.duplication]
```

## Cross-reviewer handoff
- A wrapper you want to delete that `api-contract-reviewer`/`security` rely on: defer keep/remove to them; you own the "is it earning its keep" judgment.
- Duplication that is really repo-wide: hand to `dry-reviewer`.

## Tone
Demanding, serious, high-conviction. Say clearly when the change makes the codebase messier. No softening, no "maybe rename this" when a structural simplification is available.
````

- [ ] **Step 3: Run validator**

Run: `./scripts/validate.sh`
Expected: `OK: all artifacts valid` (the two reviewer skills pass the 9-section + frontmatter check; orchestrators not present yet, so none to skip).

- [ ] **Step 4: Commit**

```bash
git add core/skills/security core/skills/craft
git commit -m "feat(skills): add security and craft reviewer rubrics"
```

---

## Task 5: Manifest + config example

**Files:**
- Create: `manifest.json`
- Create: `review-pro.config.example`

- [ ] **Step 1: Create `manifest.json`**

```json
{
  "name": "review-pro",
  "version": "0.1.0",
  "description": "Tiered AI code-review: triage -> relevant specialist reviewers -> synthesis. Cross-platform agnostic core + adapters.",
  "license": "MIT",
  "skills": [
    { "name": "review-pro-triage", "role": "orchestrator" },
    { "name": "review-pro-synthesize", "role": "orchestrator" },
    { "name": "security", "role": "reviewer" },
    { "name": "craft", "role": "reviewer" }
  ],
  "agents": [
    { "name": "review-pro-triage-subagent", "loads_skill": "review-pro-triage" },
    { "name": "review-pro-synthesize-subagent", "loads_skill": "review-pro-synthesize" },
    { "name": "security-reviewer", "loads_skill": "security" },
    { "name": "craft-reviewer", "loads_skill": "craft" }
  ]
}
```

- [ ] **Step 2: Create `review-pro.config.example`**

```yaml
# review-pro.config — copy to your repo and edit. All keys are optional.
enabled_reviewers: [security, correctness, craft, ai-antipatterns, dry, performance,
                    backend, frontend, a11y, db, api-contract, tests]   # default: all
severity_gate: low         # nitpick | low | medium | high (minimum severity to report)
thresholds:
  max_file_lines: 1000     # craft reviewer 1k-line rule
  max_function_lines: 150
  max_cyclomatic: 15
scope:
  base: main               # diff base branch
  ignore: [dist/**, vendor/**, "*.generated.*"]
stack_packs: []            # override/extend detected stacks, e.g. [typescript-react, node]
output:
  format: markdown         # markdown | json | sarif (post-MVP)
  target: terminal         # terminal | pr-comments (post-MVP) | sarif-file (post-MVP)
triggers:
  mode: full-pr            # full-pr | pre-commit (post-MVP)
```

- [ ] **Step 3: Commit**

```bash
git add manifest.json review-pro.config.example
git commit -m "feat: add plugin manifest and example config"
```

---

## Task 6: Validation harness v2 (manifest + agent references, TDD)

**Files:**
- Modify: `scripts/validate.sh` (add manifest + agent checks)
- Modify: `scripts/validate.test.sh` (add cases)

- [ ] **Step 1: Add failing tests**

Append to `scripts/validate.test.sh`, before the final `echo "---"` line:

```bash

# Case D: agent references a nonexistent skill -> fail
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
cat > "$T/core/agents/ghost-reviewer.md" <<'EOF'
---
name: ghost-reviewer
description: "loads nothing"
loads_skill: ghost
---
# ghost
EOF
cat > "$T/manifest.json" <<'EOF'
{ "skills": [{"name":"security","role":"reviewer"}], "agents": [{"name":"ghost-reviewer","loads_skill":"ghost"}] }
EOF
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "references missing skill 'ghost'"; then ok "dangling agent->skill detected"; else bad "dangling agent->skill not detected"; fi
rm -rf "$T"

# Case E: orphan skill (on disk but not in manifest) -> fail
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/orphan"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_good_reviewer "$T/core/skills/orphan/SKILL.md"
cat > "$T/manifest.json" <<'EOF'
{ "skills": [{"name":"security","role":"reviewer"}], "agents": [] }
EOF
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "orphan skill 'orphan'"; then ok "orphan skill detected"; else bad "orphan skill not detected"; fi
rm -rf "$T"
```

- [ ] **Step 2: Run test to verify the new cases fail**

Run: `bash scripts/validate.test.sh`
Expected: new cases fail (`pass` does not reach the new count), because v1 has no manifest/agent checks.

- [ ] **Step 3: Extend `validate.sh`**

Add this block to `scripts/validate.sh` immediately before the final `[[ "$errors" -eq 0 ]] ...` line:

```bash
MANIFEST="$ROOT/manifest.json"
AGENTS_DIR="$ROOT/core/agents"

# Manifest + reference checks (require python3 for JSON; warn-and-skip if absent)
json_get(){
  # $1=file $2=expr -> prints python-evaluated result
  python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
expr=sys.argv[2]
try:
    parts=expr.split('.')
    cur=d
    for p in parts: cur=cur[p]
    print(cur if not isinstance(cur,list) else '\n'.join(cur))
except Exception:
    pass
" "$1" "$2" 2>/dev/null
}

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
    # agents reference existing skills
    shopt -u nullglob
    for a in "$AGENTS_DIR"/*.md; do
      [[ -f "$a" ]] || continue
      ls_skill="$(fm_get "$a" "loads_skill")"
      [[ -n "$ls_skill" ]] || add_error "$(basename "$a"): missing frontmatter key 'loads_skill'"
      if [[ -n "$ls_skill" ]] && [[ ! -f "$SKILLS_DIR/$ls_skill/SKILL.md" ]]; then
        add_error "$(basename "$a"): references missing skill '$ls_skill'"
      fi
    done
  else
    echo "WARN: python3 not found; skipping manifest/reference checks" >&2
  fi
fi
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash scripts/validate.test.sh`
Expected: `pass=5 fail=0`.

- [ ] **Step 5: Run validator against the real repo**

Run: `./scripts/validate.sh`
Expected: `OK: all artifacts valid` (manifest declares security + craft; no orphans; no agents yet so no agent checks fire — agents are added in Task 9).

- [ ] **Step 6: Commit**

```bash
git add scripts/validate.sh scripts/validate.test.sh
git commit -m "test: extend validator with manifest + agent reference checks"
```

---

## Task 7: Triage orchestrator skill

**Files:**
- Create: `core/skills/review-pro-triage/SKILL.md`

- [ ] **Step 1: Create `core/skills/review-pro-triage/SKILL.md`**

```markdown
---
name: review-pro-triage
description: "Stage 1 of review-pro: classify changed files, detect relevant specialist reviewers, detect active stacks, scope context per reviewer, and emit a dispatch plan. Use to start a review-pro review, triage a PR/branch, or fan out reviewers."
version: 0.1.0
---

# Review-Pro Triage (Stage 1)

You are the orchestrator's first stage. You do NOT review code yourself. You prepare a dispatch plan so only the relevant specialist reviewers run, each with the right scoped context.

## Inputs
- The diff: `git diff <base>...HEAD` (default base `main`, overridable via `review-pro.config.scope.base`).
- The changed-file list: `git diff --name-only <base>...HEAD`.
- `review-pro.config` (optional): `enabled_reviewers`, `scope.ignore`, `stack_packs`.

## Steps
1. **Gather** the diff and changed-file list (run git). Read full contents of changed files (respect `scope.ignore`).
2. **Classify each changed file** into buckets: `backend | frontend | test | db-migration | config-infra | docs | build-deps`.
3. **Detect active stacks** (once): parse manifests (`package.json`, `go.mod`, `Cargo.toml`, `requirements.txt`/`pyproject.toml`, `Gemfile`, `pom.xml`). Merge with `review-pro.config.stack_packs`. Emit `active_stacks`.
4. **Decide which reviewers to dispatch** using the signal map below. Be conservative: when relevance is uncertain, dispatch. Skipping a real issue is worse than paying for one extra subagent.
5. **Scope context per dispatched reviewer** per `core/shared/context-policy.md`: every reviewer gets diff + changed files; add the reviewer-specific scoped extras.
6. **Emit the dispatch plan** (YAML below) and hand off to Stage 2 (fan-out). Do not run the reviewers inline unless the platform adapter requires it.

## Signal map (non-exhaustive)
- migration files / `CREATE|ALTER|DROP` / schema files → `db`
- auth/session/crypto/permission symbols, secret-shaped strings → `security`
- new/changed routes, handlers, controllers, service entrypoints → `backend` + `api-contract`
- loops over collections, queries in loops, bulk data → `performance`
- `.tsx/.vue/.svelte` components, interactive elements (`button`,`form`,`input`,`nav`,`dialog`) → `frontend` + `a11y`
- `.test./__tests__/spec` files, or new public functions lacking tests → `tests`
- new abstractions, large added functions, copy-paste-shaped additions → `craft` + `dry` + `ai-antipatterns`
- any non-trivial logic change → `correctness`

## Dispatch plan format
```yaml
base: <branch>
active_stacks: [<stack>, ...]
changed_files_total: <n>
dispatch:
  <reviewer>:
    context:
      changed_files: [<paths>]
      related: [<scoped extras: callers, repo-search results, schema, consumers...>]
  # reviewers not dispatched are simply absent
```

## Output discipline
Return ONLY the dispatch plan and a one-line summary. Do not review the code. Do not invent reviewers outside the roster in `manifest.json`. If `enabled_reviewers` is set, intersect your dispatch with it.
```

- [ ] **Step 2: Update `manifest.json`** — already lists `review-pro-triage`; no change needed. Verify with the validator.

- [ ] **Step 3: Run validator**

Run: `./scripts/validate.sh`
Expected: `OK: all artifacts valid` (orchestrator skills are exempt from the 9-section check).

- [ ] **Step 4: Commit**

```bash
git add core/skills/review-pro-triage
git commit -m "feat(skills): add triage orchestrator (Stage 1)"
```

---

## Task 8: Synthesis orchestrator skill

**Files:**
- Create: `core/skills/review-pro-synthesize/SKILL.md`

- [ ] **Step 1: Create `core/skills/review-pro-synthesize/SKILL.md`**

````markdown
---
name: review-pro-synthesize
description: "Stage 3 of review-pro: dedup, weight, resolve conflicts, calibrate severity, and produce the final verdict + report from specialist findings. Use to merge reviewer results into one review verdict."
version: 0.1.0
---

# Review-Pro Synthesis (Stage 3)

You are the orchestrator's final stage. You receive the structured findings from all dispatched reviewers and produce ONE unified review.

## Steps
1. **Collect** all finding blocks from the dispatched reviewers.
2. **Dedup** by `(file, line±5, category-root, overlap_hints)`: the same issue flagged by multiple reviewers collapses into one.
3. **Weight:** a finding flagged by ≥2 reviewers gets a conviction boost — annotate it "flagged by N reviewers".
4. **Resolve conflicts** by ownership — the domain owner sets severity (see table).
5. **Calibrate severity:** enforce the anti-overreporting bar. Downgrade anything not fully traced to evidence. Never upgrade beyond what a specialist justified.
6. **Verdict** + prioritized findings + remediations.

## Conflict ownership
| Domain | Severity authority |
|---|---|
| security / auth / secrets | security-reviewer |
| data integrity / migrations | db-reviewer |
| contract / back-compat | api-contract-reviewer |
| maintainability / structure | craft-reviewer |
| performance | performance-reviewer |
| test correctness | tests-reviewer |
| accessibility | a11y-reviewer |

## Verdict (see core/shared/severity.md)
- **BLOCK:** any unaddressed Critical or High.
- **REQUEST CHANGES:** any Medium or above.
- **APPROVE:** only Low/Nitpick, or no findings.

## Output
A markdown report. Lead with the verdict and Critical/High. Do not restate raw specialist dumps — present the unified, deduped view.

```
## Verdict: BLOCK | REQUEST CHANGES | APPROVE

### Critical
- [Critical] src/api/orders.ts:42 — missing ownership check
  impact: any authenticated user can update another user's order
  remedy: authorize(ctx.userId === order.userId)
  flagged by: security, backend

### High
...

### Medium / Low / Nitpick
...
```
````

- [ ] **Step 2: Run validator**

Run: `./scripts/validate.sh`
Expected: `OK: all artifacts valid`.

- [ ] **Step 3: Commit**

```bash
git add core/skills/review-pro-synthesize
git commit -m "feat(skills): add synthesis orchestrator (Stage 3)"
```

---

## Task 9: Subagent role definitions

**Files:**
- Create: `core/agents/review-pro-triage-subagent.md`
- Create: `core/agents/review-pro-synthesize-subagent.md`
- Create: `core/agents/security-reviewer.md`
- Create: `core/agents/craft-reviewer.md`

- [ ] **Step 1: Create `core/agents/review-pro-triage-subagent.md`**

```markdown
---
name: review-pro-triage-subagent
description: Triage subagent (Stage 1). Classifies the diff, detects relevant reviewers + active stacks, scopes context, and emits a dispatch plan. Loads the review-pro-triage skill.
loads_skill: review-pro-triage
---

# Review-Pro Triage (subagent)

You are a **review-pro subagent**. Load the `review-pro-triage` skill and follow it exactly.

## Work
1. Gather the diff and changed files against the configured base (default `main`).
2. Classify files, detect active stacks, decide which reviewers to dispatch, and scope each reviewer's context.
3. Emit the dispatch plan in the skill's YAML format and a one-line summary.

You do NOT review the code and you do NOT spawn reviewers — the platform adapter handles fan-out from your dispatch plan.
```

- [ ] **Step 2: Create `core/agents/review-pro-synthesize-subagent.md`**

```markdown
---
name: review-pro-synthesize-subagent
description: Synthesis subagent (Stage 3). Dedup, weight, resolve conflicts, calibrate severity, and produce the final verdict + report. Loads the review-pro-synthesize skill.
loads_skill: review-pro-synthesize
---

# Review-Pro Synthesis (subagent)

You are a **review-pro subagent**. Load the `review-pro-synthesize` skill and follow it exactly.

## Work
1. Receive the structured findings from all dispatched reviewers.
2. Dedup, weight overlapping findings, resolve conflicts by domain ownership, calibrate severity.
3. Emit the unified verdict + prioritized report.

Do NOT spawn nested subagents.
```

- [ ] **Step 3: Create `core/agents/security-reviewer.md`**

```markdown
---
name: security-reviewer
description: Security reviewer subagent. Invoked by the review-pro orchestrator after triage gathers scoped context. Loads the `security` skill as its rubric and returns structured findings.
loads_skill: security
---

# Security Reviewer (subagent)

You are a **review-pro subagent**. The orchestrator composed your effective rubric (core `security` skill + active stack packs) and gathered your scoped context. Your prompt contains labeled sections: `### Rubric`, `### Changed file contents`, and any `### Related context`.

## Work
1. Apply the rubric ONLY to added/modified code. Trace callers/callees from your related context when needed to confirm impact.
2. Output structured finding blocks in the rubric's schema. Calibrate severity honestly. Never present a finding with unfinished research.
3. Do NOT spawn nested subagents.
```

- [ ] **Step 4: Create `core/agents/craft-reviewer.md`**

```markdown
---
name: craft-reviewer
description: Craft (maintainability) reviewer subagent. Invoked by the review-pro orchestrator after triage gathers scoped context. Loads the `craft` skill as its rubric and returns structured findings.
loads_skill: craft
---

# Craft Reviewer (subagent)

You are a **review-pro subagent**. The orchestrator composed your effective rubric (core `craft` skill + active stack packs) and gathered your scoped context. Your prompt contains labeled sections: `### Rubric`, `### Changed file contents`, and any `### Related context`.

## Work
1. Apply the rubric ONLY to added/modified code plus neighboring modules. Search aggressively for code-judo moves.
2. Output structured finding blocks in the rubric's schema. Calibrate severity honestly. Never present a finding with unfinished research.
3. Do NOT spawn nested subagents.
```

- [ ] **Step 5: Run validator**

Run: `./scripts/validate.sh`
Expected: `OK: all artifacts valid` (all 4 agents reference existing skills; manifest lists them all).

- [ ] **Step 6: Commit**

```bash
git add core/agents/
git commit -m "feat(agents): add triage, synthesis, security, craft subagents"
```

---

## Task 10: opencode adapter

**Files:**
- Create: `adapters/opencode/install.sh`
- Create: `adapters/opencode/README.md`

- [ ] **Step 1: Create `adapters/opencode/install.sh`**

```bash
#!/usr/bin/env bash
# adapters/opencode/install.sh — install review-pro core into opencode.
# opencode loads skills from $OC_HOME/skills/<name>/SKILL.md.
# Agents are copied to $OC_HOME/agents/ — confirm your opencode loads agents from there.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OC_HOME="${OPENCODE_HOME:-$HOME/.config/opencode}"
SKILLS_DST="$OC_HOME/skills"
AGENTS_DST="$OC_HOME/agents"

echo "Installing review-pro into $OC_HOME"
mkdir -p "$SKILLS_DST" "$AGENTS_DST"

for skill_dir in "$ROOT"/core/skills/*/; do
  name="$(basename "$skill_dir")"
  cp -R "$skill_dir" "$SKILLS_DST/$name"
  echo "  skill: $name"
done

shopt -s nullglob
for agent in "$ROOT"/core/agents/*.md; do
  cp "$agent" "$AGENTS_DST/"
  echo "  agent: $(basename "$agent")"
done
shopt -u nullglob

echo "Done."
echo "Verify opencode loads agents from $AGENTS_DST (see adapters/opencode/README.md)."
```

Make executable: `chmod +x adapters/opencode/install.sh`

- [ ] **Step 2: Create `adapters/opencode/README.md`**

```markdown
# review-pro — opencode adapter

Installs the review-pro agnostic core into opencode.

## Install

```bash
bash adapters/opencode/install.sh
# or, to target a custom opencode home:
OPENCODE_HOME=/path/to/.config/opencode bash adapters/opencode/install.sh
```

## What it does
- Copies each `core/skills/<name>/` to `$OC_HOME/skills/<name>/` (opencode loads `SKILL.md` from there).
- Copies each `core/agents/*.md` to `$OC_HOME/agents/`.

## Confirming agent loading
opencode skill loading from `$OC_HOME/skills/` is confirmed. Agent/subagent loading paths can vary by opencode version — after install, verify your agents appear (e.g., list available agents in your opencode session). If your opencode expects agents elsewhere, copy `core/agents/*.md` to that location and adjust this script.

## Running a review
1. In your repo, run the **triage** skill on the current branch's diff.
2. From triage's dispatch plan, invoke the listed reviewer subagents in parallel, passing each its scoped context and its effective rubric (core skill + active stack packs).
3. Pass all reviewer outputs to the **synthesize** subagent for the final verdict + report.

> Stack packs (Phase 3) are layered onto reviewer rubrics at dispatch time. Until then, reviewers run on their core rubric only.
```

- [ ] **Step 3: Test the install (smoke)**

Install into a temp opencode home and assert the expected files land:
```bash
TMPHOME="$(mktemp -d)"
OPENCODE_HOME="$TMPHOME" bash adapters/opencode/install.sh >/dev/null
test -f "$TMPHOME/skills/security/SKILL.md" && echo "security skill installed"
test -f "$TMPHOME/agents/security-reviewer.md" && echo "security agent installed"
test -f "$TMPHOME/skills/review-pro-triage/SKILL.md" && echo "triage skill installed"
rm -rf "$TMPHOME"
```
Expected: all three echo lines print.

- [ ] **Step 4: Commit**

```bash
git add adapters/opencode/
git commit -m "feat(adapters): add opencode install shim"
```

---

## Task 11: Project README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Create `README.md`**

````markdown
# review-pro

Tiered AI code-review: **triage → relevant specialist reviewers → synthesis**. Reviews code written by AI agents, using AI agents. An open-source, cross-platform alternative to [cursor/plugins — thermos](https://github.com/cursor/plugins/tree/main/thermos).

## Why

`thermos` runs two reviewers on every review. review-pro runs a **triage** stage first, then dispatches only the **relevant specialists**, each with **scoped context** (not the whole diff), then **synthesizes** one verdict. This keeps small PRs cheap and large PRs deep, and adds an **AI-code anti-patterns** lens that thermos lacks.

## Architecture

```
triage (Stage 1) -> fan-out (Stage 2, parallel specialists) -> synthesis (Stage 3)
```

- **Triage** classifies the diff, picks relevant reviewers, detects active stacks, scopes context, emits a dispatch plan.
- **Fan-out** runs only the selected specialists in parallel; each loads an effective rubric = core skill + active stack packs.
- **Synthesis** dedups, weights, resolves conflicts by domain ownership, calibrates severity, emits one verdict.

See `docs/superpowers/specs/2026-06-20-review-pro-design.md` for the full design.

## Status (v0.1)

Working slice: foundation + validation harness + shared docs + `security` & `craft` reviewers + `triage` & `synthesize` orchestrators + subagents + the **opencode** adapter.

Roadmap: 8 more reviewers (Phase 2), stack packs `typescript-react` & `node` (Phase 3), Cursor & Claude Code adapters, SARIF / PR-comment output, pre-commit mode.

## Install (opencode)

```bash
bash adapters/opencode/install.sh
```
See `adapters/opencode/README.md` for details and agent-loading notes.

## Configure (optional, per repo)

Copy `review-pro.config.example` to `review-pro.config` and edit (enabled reviewers, severity gate, thresholds, base branch, ignore globs, stack packs).

## Validate

```bash
./scripts/validate.sh        # structural check: frontmatter, sections, manifest, references
bash scripts/validate.test.sh # validator unit tests
```

## License

MIT. See `LICENSE`.
````

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add project README"
```

---

## Task 12: Final validation + end-to-end smoke + self-review

- [ ] **Step 1: Full validation run**

Run:
```bash
./scripts/validate.sh && bash scripts/validate.test.sh
```
Expected: `OK: all artifacts valid`, then `pass=5 fail=0`.

- [ ] **Step 2: Manual end-to-end review smoke (the real test of a prompt project)**

On a sample branch with a deliberate security + craft issue (e.g., an unauthenticated mutating endpoint added to a 1100-line file):
1. Run the **triage** skill. Confirm it emits a dispatch plan that includes `security` and `craft`.
2. For each dispatched reviewer, run its subagent with its scoped context + effective rubric. Confirm each returns structured finding blocks in the shared schema.
3. Run the **synthesize** subagent over the collected findings. Confirm it dedups, applies the verdict rule, and outputs a `BLOCK` with the two findings.
4. Capture the outputs; if any stage misbehaves, fix the offending skill and re-run.

Expected: a single deduped report with verdict `BLOCK`, the security finding at High/Critical, the craft finding at High.

- [ ] **Step 3: Plan self-review (executing engineer)**

Confirm against `docs/superpowers/specs/2026-06-20-review-pro-design.md`:
- §4 rubric anatomy (11-part) → security & craft skills implement it (Ambition is folded into craft; both implement the 9 enforced sections + content). ✔
- §5 output schema → shared/output-schema.md + both reviewer skills use it. ✔
- §6 context policy → shared/context-policy.md. ✔
- §7 severity & verdict → shared/severity.md + synthesis skill. ✔
- §8 stack packs → mechanism documented (glossary + triage skill); actual packs are Phase 3. ✔ (out of v0.1 scope)
- §10 opencode adapter → Task 10. ✔
- §11 repo structure → core/{skills,agents,shared}, adapters/opencode, scripts, docs all present. ✔
- §12 MVP scope → foundation + opencode adapter + 2 reviewers (of 12) done; remaining 10 are Phase 2. ✔

- [ ] **Step 4: Final commit (if any smoke-test fixes were made)**

```bash
git add -A
git commit -m "chore: phase 1 complete — validation + smoke review pass"
```

---

## Phase 1 done — what's next

- **Phase 2:** the remaining 10 reviewer skills (`correctness`, `ai-antipatterns`, `dry`, `performance`, `backend`, `frontend`, `a11y`, `db`, `api-contract`, `tests`) + their subagents + manifest entries. Each is an independent unit following the Task 4 template; highly parallelizable across subagents.
- **Phase 3:** stack packs `typescript-react` and `node`, plus the runtime composition note wired into the opencode fan-out.
