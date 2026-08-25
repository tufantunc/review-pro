# External Premise Verification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a diff's rationale cites a specific external artifact, the reviewer that owns the claim verifies it against that artifact, or states plainly that it could not.

**Architecture:** Triage extracts premises from the two channels a reviewer cannot see (commit messages, PR body) and routes each to exactly one owning reviewer, which dispatches that reviewer. The orchestrator passes the premise as an `### External premises` prompt section. The reviewer verifies through a fixed channel order that prefers the locally resolved dependency source over the network, and records which channel settled it. Three outcomes: contradicted becomes a normal finding under an existing category root, confirmed becomes a ledger row, unverifiable becomes a dedicated block plus `confidence: low` on anything resting on it.

**Tech Stack:** Markdown skill rubrics and agent bodies, bash 3.2 validator, bash meta-test suite. No code changes to the CLI.

**Spec:** `docs/superpowers/specs/2026-08-25-external-premise-verification-design.md`

## Global Constraints

- **No new finding-schema field.** `confidence: high | medium | low` already exists in all thirteen rubrics; the unverifiable outcome reuses it.
- **No new category root.** The registry in `review-pro-synthesize/SKILL.md` is one root per reviewer, exactly thirteen. A contradicted premise files under whatever concern it damages.
- **Every rule lands in both the rubric and the agent body.** The body is the copy that reaches the running subagent; the rubric is the copy that `review-pro/SKILL.md`'s documented inline path applies. A rule in only one silently disables the feature on the other path.
- **bash 3.2 (macOS).** `"${arr[@]}"` on an empty array errors under `set -u`. Drive loops off newline-delimited strings, as the existing validator does.
- **No em dash (`—`), `·`, or `→` in any prose written by this plan.** Restructure the sentence instead.
- **Meta-test cases put the positive control before the negative mutation.** Without it, a passing assertion can come from the fixture never having contained the string.
- **Insert new meta-test cases BEFORE the summary block.** The suite exits via `trap 'exit $(( fail > 0 ))' EXIT`; a case appended after `echo "---"` still runs, but keep the ordering convention.
- **`~~~` in this plan is escaping, never content.** Blocks nested inside a task's
  `markdown` example are fenced with `~~~` only so they do not terminate the surrounding
  fence in this document. When you copy such a block into a product file under `core/`,
  convert it to a triple-backtick fence, which is what every other fence in those files
  uses. `grep -rn '^~~~' core/` must return nothing. Task 3 shipped 12 of these before it
  was caught.
- **Prose you add matches the file's own wrapping.** The six reviewer files and the
  orchestrator skills keep one line per paragraph with no hard wrapping. This plan's own
  code blocks are wrapped to about 88 characters for readability here; reflow them when
  they land.
- Reviewer count stays **thirteen**. The published-count guard must not move.
- Target suite state at the end: validator `OK`, meta-tests **95/95**, CLI 49/49, site build exit 0, no `docs/` drift.

---

### Task 1: The channel order in shared context policy

The reviewer-facing rule that makes external verification reproducible. Written first because Tasks 2 and 3 refer to it.

**Files:**
- Modify: `core/shared/context-policy.md`
- Modify: `scripts/validate.sh` (after the spec-axis load-bearing block, which currently ends at line 179)
- Test: `scripts/validate.test.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: the exact string `which channel settled`, which Task 1's guard greps for and Tasks 2 and 3 cite in prose.

- [ ] **Step 1: Write the failing test**

Insert before the summary block in `scripts/validate.test.sh`:

```bash
# Case AB: the settling-channel record in context-policy. Its absence makes a
# network answer indistinguishable from a local one, so reviews stop being
# reproducible without any check failing.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/shared" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
printf 'Record which channel settled the premise.\n' > "$T/core/shared/context-policy.md"
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "settling-channel record is gone"; then bad "settling-channel control fired on an intact fixture"; else ok "settling-channel control silent when present"; fi
printf 'Verify the premise outside the repo.\n' > "$T/core/shared/context-policy.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "settling-channel record is gone"; then ok "removed settling-channel record detected"; else bad "removed settling-channel record not detected"; fi
rm -rf "$T"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash scripts/validate.test.sh 2>&1 | tail -2`
Expected: `pass=74 fail=1`. The failing line is `not ok - removed settling-channel record detected`, because no guard exists yet. The positive-control half passes vacuously, which is exactly why the negative half has to exist.

- [ ] **Step 3: Add the guard**

In `scripts/validate.sh`, after the `for f in "$SKILLS_DIR/spec/SKILL.md" ... done` block that ends the spec-axis guards:

```bash
CTX_POLICY="$SHARED_DIR/context-policy.md"
if [[ -f "$CTX_POLICY" ]]; then
  grep -qF 'which channel settled' "$CTX_POLICY" \
    || add_error "shared/context-policy.md: the settling-channel record is gone - a network answer becomes indistinguishable from a local one and reviews stop being reproducible"
fi
```

`SHARED_DIR` is already defined at line 121. Place this block after that definition, never before it, or the run dies with `SHARED_DIR: unbound variable`.

- [ ] **Step 4: Run the test to verify it passes and the real repo now fails**

Run: `bash scripts/validate.test.sh 2>&1 | tail -2`
Expected: `pass=77 fail=0`

Run: `bash scripts/validate.sh`
Expected: FAIL, one error, `shared/context-policy.md: the settling-channel record is gone`. This is the red state for Step 5.

- [ ] **Step 5: Add the policy content**

Append to `core/shared/context-policy.md`:

```markdown
## Verifying a premise that points outside the repo

When a change's rationale cites a specific external artifact, verify it in this order
and stop at the first channel that settles it:

1. **The locally resolved dependency source.** `node_modules`, `~/.nuget/packages`,
   `~/.cargo/registry`, `vendor/`. Offline, deterministic, and the one place where "at
   the pinned version" is literally true, because it is what the build resolved to.
2. **Lockfile and manifest**, to establish the version the claim must hold at.
3. **The network.** Upstream issue, PR, changelog, release notes.
4. Nothing.

Prefer the first channel even when the third looks easier. In the pilot that motivated
this rule, both halves of the centerpiece finding were visible in the installed package
source, and the one claim that went unsettled was blocked by the package being absent
from the local cache rather than by any lack of network.

Record **which channel settled** the premise, not merely the outcome. A network answer
is not reproducible: the same diff reviewed tomorrow can reach a different conclusion,
and a reader who cannot tell a durable verification from a perishable one cannot judge
either.
```

- [ ] **Step 6: Run everything**

Run: `bash scripts/validate.sh && bash scripts/validate.test.sh 2>&1 | tail -1`
Expected: `OK: all artifacts valid` then `pass=77 fail=0`

Step 2's `pass=74 fail=1` is the count with Case AB alone. Task 1 also carries Case AB2,
added in review: the `which channel settled` grep guards the record-the-channel sentence
but not the channel order itself, which a reviewer demonstrated by deleting the ordered
list while leaving that sentence intact and watching the validator stay silent. AB2
guards `locally resolved dependency source` so deleting the local-first channel fires.
Every count from here on includes both cases.

- [ ] **Step 7: Commit**

```bash
git add core/shared/context-policy.md scripts/validate.sh scripts/validate.test.sh
git commit -m "feat: order the channels for verifying an external premise (#13)"
```

---

### Task 2: Triage extracts and routes premises

**Files:**
- Modify: `core/skills/review-pro-triage/SKILL.md`
- Modify: `core/skills/review-pro/SKILL.md` (step 2's prompt-section list)
- Modify: `scripts/validate.sh`
- Test: `scripts/validate.test.sh` (including `write_orchestrator`, which MUST be updated)

**Interfaces:**
- Consumes: `which channel settled` from Task 1, cited in the triage prose that tells the reviewer where the rule lives.
- Produces: the plan key `external_premises` with subkeys `claim`, `cited`, `source`, `pinned` (optional), `owner`; the exact strings `Assigning a premise`, `does not verify the premise`, and the prompt section heading `### External premises`. Task 3's reviewer contract consumes all of these.

- [ ] **Step 1: Update the meta-test fixtures FIRST**

This step is not optional and it is not cosmetic. Adding a load-bearing grep on the triage skill invalidates `write_orchestrator`'s fixture, and Case A ("clean tree passes") goes red for a reason unrelated to what it tests.

In `scripts/validate.test.sh`, in `write_orchestrator`'s `review-pro-triage` branch, change:

```
## Dispatch plan format
spec_source:
  kind: none
Dispatch spec if and only if a spec was resolved.
## Output discipline
```

to:

```
## Dispatch plan format
spec_source:
  kind: none
external_premises: []
Dispatch spec if and only if a spec was resolved.
Assigning a premise to a reviewer dispatches that reviewer.
Triage does not verify the premise itself.
## Output discipline
```

The blast radius is **one** case, not eleven. Nearly every case asserts that a specific error message appears, and extra errors leave those assertions alone; only Case A asserts a clean pass.

- [ ] **Step 2: Write the three failing tests**

Insert before the summary block:

```bash
# Case X: triage's external_premises contract. Positive control first, so a passing
# assertion cannot come from the fixture simply never having had the string.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/review-pro-triage" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_orchestrator "$T/core/skills/review-pro-triage/SKILL.md" review-pro-triage
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"review-pro-triage","role":"orchestrator"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "no 'external_premises'"; then bad "external_premises control fired on an intact fixture"; else ok "external_premises control silent when present"; fi
grep -v '^external_premises: \[\]$' "$T/core/skills/review-pro-triage/SKILL.md" > "$T/tmp" && mv "$T/tmp" "$T/core/skills/review-pro-triage/SKILL.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "no 'external_premises'"; then ok "removed external_premises detected"; else bad "removed external_premises not detected"; fi
rm -rf "$T"

# Case Y: the assign-dispatches rule, without which a premise is routed to a
# reviewer the signal map never dispatches and nothing reports the gap.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/review-pro-triage" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_orchestrator "$T/core/skills/review-pro-triage/SKILL.md" review-pro-triage
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"review-pro-triage","role":"orchestrator"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "assign-dispatches rule is gone"; then bad "assign-dispatches control fired on an intact fixture"; else ok "assign-dispatches control silent when present"; fi
grep -v '^Assigning a premise' "$T/core/skills/review-pro-triage/SKILL.md" > "$T/tmp" && mv "$T/tmp" "$T/core/skills/review-pro-triage/SKILL.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "assign-dispatches rule is gone"; then ok "removed assign-dispatches rule detected"; else bad "removed assign-dispatches rule not detected"; fi
rm -rf "$T"

# Case Z: the prohibition on triage verifying premises itself.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/review-pro-triage" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_orchestrator "$T/core/skills/review-pro-triage/SKILL.md" review-pro-triage
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"review-pro-triage","role":"orchestrator"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "no-verification prohibition is gone"; then bad "no-verification control fired on an intact fixture"; else ok "no-verification control silent when present"; fi
grep -v 'does not verify the premise' "$T/core/skills/review-pro-triage/SKILL.md" > "$T/tmp" && mv "$T/tmp" "$T/core/skills/review-pro-triage/SKILL.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "no-verification prohibition is gone"; then ok "removed no-verification prohibition detected"; else bad "removed no-verification prohibition not detected"; fi
rm -rf "$T"

# Case AE: the orchestrator's prompt section. Without it triage routes premises the
# orchestrator never passes on, so the whole chain runs and verifies nothing.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/review-pro" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
cat > "$T/core/skills/review-pro/SKILL.md" <<'EOFO'
---
name: review-pro
description: "orchestrator"
---
# Review-Pro
Dedup within each axis, spec findings on the quoted requirement.
### External premises
EOFO
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"review-pro","role":"orchestrator"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "prompt section is gone"; then bad "orchestrator premise-section control fired on an intact fixture"; else ok "orchestrator premise-section control silent when present"; fi
grep -v '^### External premises$' "$T/core/skills/review-pro/SKILL.md" > "$T/tmp" && mv "$T/tmp" "$T/core/skills/review-pro/SKILL.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "prompt section is gone"; then ok "removed orchestrator premise section detected"; else bad "removed orchestrator premise section not detected"; fi
rm -rf "$T"
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `bash scripts/validate.test.sh 2>&1 | tail -2`
Expected: `pass=81 fail=4`. Four failures, one per case, all of the form `not ok - removed <thing> detected`.

- [ ] **Step 4: Add the four guards**

In `scripts/validate.sh`, extend the `if [[ -f "$TRIAGE_MD" ]]` block that currently holds only the `spec_source` guard:

```bash
  grep -qF 'external_premises' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: no 'external_premises' - external premises are never extracted or routed, so no reviewer is ever asked to verify one"
  grep -qF 'Assigning a premise' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: the assign-dispatches rule is gone - a premise can be routed to a reviewer the signal map never dispatches, and nothing reports that it was"
  grep -qF 'does not verify the premise' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: the no-verification prohibition is gone - triage settling premises itself breaks the one-owner rule and produces verifications nobody can attribute"
```

And inside the **existing** `if [[ -f "$ORCH_MD" ]]` block at line 176, alongside the `quoted requirement` guard. Do not declare a second `ORCH_MD`:

```bash
  grep -qF '### External premises' "$ORCH_MD" \
    || add_error "review-pro/SKILL.md: the '### External premises' prompt section is gone - triage routes premises the orchestrator then never passes to the owning reviewer"
```

- [ ] **Step 5: Run tests, confirm green, confirm the real repo is red**

Run: `bash scripts/validate.test.sh 2>&1 | tail -1`
Expected: `pass=85 fail=0`

Run: `bash scripts/validate.sh`
Expected: FAIL with exactly four errors, the four just added.

- [ ] **Step 6: Add the triage step**

In `core/skills/review-pro-triage/SKILL.md`, insert as a new numbered step after step 6 (spec resolution), renumbering what follows:

```markdown
7. **Extract external premises.** Gather your own sources; do not hang this on step 6,
   whose chain stops at the first hit and therefore never reads the PR body when the
   user passed a spec by hand.

   Sources, in the two channels a reviewer cannot see for itself:
   - **Commit messages** on the branch (`git log <base>..HEAD`). No `gh` needed.
   - **The PR body**, via `gh pr view`. Its absence is an ordinary condition.

   Code comments in changed files are **not** yours: they are already in every
   reviewer's baseline context, and scanning them here would route the same premise
   twice.

   A premise qualifies only when the rationale points at a **specific, addressable
   external artifact**: an upstream issue or PR number, a changelog entry, a CVE, a
   release note, an RFC. "Fixed upstream" with no number qualifies, because which fix
   is determinable from the package version. A claim that is merely ungrounded in the
   repo does **not** qualify; that threshold would turn every review into a web crawl.

   Assign exactly one `owner`:

   | The premise justifies | Owner |
   |---|---|
   | Adding, removing, or bumping a dependency | `ai-antipatterns` |
   | A behaviour-equivalence claim across a dependency change | `correctness` |
   | An API surface or version-floor claim | `api-contract` |
   | Anything else | `ai-antipatterns` |

   **Assigning a premise to a reviewer dispatches that reviewer**, whatever the signal
   map in step 4 concluded. Otherwise a premise can be routed to a reviewer that never
   runs, and nothing reports the gap.

   **Triage does not verify the premise itself.** Extract, route, stop. A triage that
   settles a premise breaks the one-owner rule and produces a verification no reader can
   attribute to a reviewer.

   At most **three** premises, chosen by what the diff most depends on. State any
   dropped count in the plan: a silent cap reads to the next reader as complete
   coverage. Emit nothing when there are none.
```

Then add to the dispatch plan YAML, after the `spec_source` block:

```yaml
external_premises:                    # omit the key entirely when there are none
  - claim: "<the rationale, quoted>"
    cited: <upstream ref, changelog entry, CVE, or version>
    source: commit-message | pr-body
    pinned: <package old -> new>      # optional; when the diff pins the version
    owner: ai-antipatterns | correctness | api-contract
premises_dropped: <n>                 # omit when zero
```

- [ ] **Step 7: Add the orchestrator prompt section**

In `core/skills/review-pro/SKILL.md`, in the step-2 prompt-section list, after the `### Spec text` bullet:

```markdown
   - `### External premises`, for the owning reviewer only: the entries from triage's
     `external_premises` whose `owner` is this reviewer, verbatim. Omit the section for
     every other reviewer. Verification channels and the requirement to record which
     channel settled a premise live in `core/shared/context-policy.md`.
```

- [ ] **Step 8: Run everything**

Run: `bash scripts/validate.sh && bash scripts/validate.test.sh 2>&1 | tail -1`
Expected: `OK: all artifacts valid` then `pass=85 fail=0`

- [ ] **Step 9: Commit**

```bash
git add core/skills/review-pro-triage/SKILL.md core/skills/review-pro/SKILL.md scripts/validate.sh scripts/validate.test.sh
git commit -m "feat: extract and route external premises in triage (#13)"
```

---

### Task 3: The reviewer contract for the three owners

**Files:**
- Modify: `core/skills/ai-antipatterns/SKILL.md`, `core/skills/correctness/SKILL.md`, `core/skills/api-contract/SKILL.md`
- Modify: `core/agents/ai-antipatterns-reviewer.md`, `core/agents/correctness-reviewer.md`, `core/agents/api-contract-reviewer.md`
- Modify: `scripts/validate.sh`
- Test: `scripts/validate.test.sh`

**Interfaces:**
- Consumes: `### External premises` from Task 2, and the channel order from Task 1.
- Produces: the exact strings `## Premise verification` and `never silently trust`, in all six files. Task 4's ledger consumes the block's field names: `premise`, `cited`, `settled_by`, `outcome`, `finding`, `blocked`.

- [ ] **Step 1: Write the failing tests**

Insert before the summary block. The loop covers a rubric and a body, because a rule present in only one disables the feature on the other path:

```bash
# Case AC/AD: the two owner-side rules, checked in the rubric AND the agent body.
# Both copies, because the body is what reaches the subagent and the rubric is what
# review-pro/SKILL.md's inline path applies; a rule in only one silently disables
# the feature on the other path.
for pair in "core/skills/ai-antipatterns/SKILL.md" "core/agents/ai-antipatterns-reviewer.md"; do
  T=$(mktemp -d)
  mkdir -p "$T/core/skills/security" "$T/core/skills/ai-antipatterns" "$T/core/agents"
  write_good_reviewer "$T/core/skills/security/SKILL.md"
  if [[ "$pair" == core/skills/* ]]; then
    write_good_reviewer "$T/$pair"
  else
    write_good_agent_body "$T/$pair" ai-antipatterns-reviewer
  fi
  printf '## Premise verification\nnever silently trust an unsettled premise.\n' >> "$T/$pair"
  cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"ai-antipatterns","role":"reviewer"}], "agents": [] }
JSON
  out=$(bash "$VALIDATE" "$T" 2>&1 || true)
  if echo "$out" | grep -q "premise-verification block is gone"; then bad "$pair: premise-verification control fired on an intact fixture"; else ok "$pair: premise-verification control silent when present"; fi
  if echo "$out" | grep -q "unsettled-premise confidence rule is gone"; then bad "$pair: confidence-rule control fired on an intact fixture"; else ok "$pair: confidence-rule control silent when present"; fi
  grep -v '## Premise verification' "$T/$pair" > "$T/tmp" && mv "$T/tmp" "$T/$pair"
  out=$(bash "$VALIDATE" "$T" 2>&1 || true)
  if echo "$out" | grep -q "premise-verification block is gone"; then ok "$pair: removed premise-verification block detected"; else bad "$pair: removed premise-verification block not detected"; fi
  grep -v 'never silently trust' "$T/$pair" > "$T/tmp" && mv "$T/tmp" "$T/$pair"
  out=$(bash "$VALIDATE" "$T" 2>&1 || true)
  if echo "$out" | grep -q "unsettled-premise confidence rule is gone"; then ok "$pair: removed confidence rule detected"; else bad "$pair: removed confidence rule not detected"; fi
  rm -rf "$T"
done
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bash scripts/validate.test.sh 2>&1 | tail -2`
Expected: `pass=89 fail=4`. Four failures, the four `removed ... detected` lines across the two pair iterations.

- [ ] **Step 3: Add the two guards**

In `scripts/validate.sh`, after the Task 2 triage guards:

```bash
# Both copies, for the same reason as the spec axis: the agent body is what reaches
# the running subagent, and the rubric is what review-pro/SKILL.md's inline path applies.
for f in "$SKILLS_DIR/ai-antipatterns/SKILL.md" "$SKILLS_DIR/correctness/SKILL.md" \
         "$SKILLS_DIR/api-contract/SKILL.md" "$ROOT/core/agents/ai-antipatterns-reviewer.md" \
         "$ROOT/core/agents/correctness-reviewer.md" "$ROOT/core/agents/api-contract-reviewer.md"; do
  [[ -f "$f" ]] || continue
  grep -qF '## Premise verification' "$f" \
    || add_error "$(basename "$f"): the premise-verification block is gone - a premise routed to this reviewer could vanish without the report showing it"
  grep -qF 'never silently trust' "$f" \
    || add_error "$(basename "$f"): the unsettled-premise confidence rule is gone - a finding resting on an unverified premise would report at full confidence"
done
```

The `[[ -f "$f" ]] || continue` is load-bearing: no existing fixture creates these three names, and an unguarded check would fire on every fixture in the suite.

- [ ] **Step 4: Run tests, confirm green, confirm the real repo is red**

Run: `bash scripts/validate.test.sh 2>&1 | tail -1`
Expected: `pass=93 fail=0`

Run: `bash scripts/validate.sh 2>&1 | grep -c "premise"`
Expected: `12`. Two guards times six files, all red until Step 5.

- [ ] **Step 5: Add the clause to all three rubrics**

Append to each of `core/skills/ai-antipatterns/SKILL.md`, `core/skills/correctness/SKILL.md`, and `core/skills/api-contract/SKILL.md`, before `## Tone`. Adjust only the leading sentence to name the reviewer's own concern; keep the rest byte-identical across the three so the greps and the reader both find the same rule:

```markdown
## External premises

When the task prompt carries an `### External premises` section, each entry is a claim
this change's rationale rests on that cannot be settled inside the repo. Verify it using
the channel order in `shared/context-policy.md`, and record which channel settled it.

- **Contradicted.** File a normal finding under your own existing category, chosen by
  what the false premise *damages*, not by the fact that a premise was false. Cite the
  external source in `evidence_refs` with its channel and version, because a versionless
  upstream citation cannot be rechecked:
  `[~/.nuget/packages/openai/2.12.0/lib/.../ContainerFileResource.cs:41]` or
  `[openai/openai-dotnet@OpenAI_2.12.0]`. Severity from the usual bar,
  `confidence: high`.
- **Confirmed.** No finding.
- **Unverifiable.** No finding either.

Whichever of the three it was, account for **every** premise you were handed in one
block. Silence is not an outcome: a premise that was routed to you and then left no
trace is indistinguishable from one nobody checked, and removing exactly that ambiguity
is why this section exists.

~~~
## Premise verification
- premise: <the claim, quoted>
  cited: <the artifact>
  settled_by: local-package-cache | lockfile | network | none
  outcome: contradicted | confirmed | unverified
  finding: <the category you filed it under>   # only when contradicted
  blocked: <what stopped you>                  # only when unverified
~~~

A finding that rests on a premise you could not settle carries `confidence: low` and
says so in the block. **Never silently skip, never silently trust.**
```

- [ ] **Step 6: Add the same clause to all three agent bodies**

Append the identical section to `core/agents/ai-antipatterns-reviewer.md`, `core/agents/correctness-reviewer.md`, and `core/agents/api-contract-reviewer.md`. The bodies do not load `core/shared/`, so replace the pointer sentence with the channel order inline:

```markdown
## External premises

When the task prompt carries an `### External premises` section, each entry is a claim
this change's rationale rests on that cannot be settled inside the repo. Verify it in
this order, stopping at the first channel that settles it: the locally resolved
dependency source (`node_modules`, `~/.nuget/packages`, `~/.cargo/registry`, `vendor/`),
then the lockfile and manifest to fix the version the claim must hold at, then the
network, then nothing. Prefer the first even when the network looks easier, and record
**which channel settled** the premise; a network answer is not reproducible.

- **Contradicted.** File a normal finding under your own existing category, chosen by
  what the false premise *damages*, not by the fact that a premise was false. Cite the
  external source in `evidence_refs` with its channel and version. `confidence: high`.
- **Confirmed.** No finding.
- **Unverifiable.** No finding either.

Whichever of the three it was, account for **every** premise you were handed in one
block. Silence is not an outcome.

~~~
## Premise verification
- premise: <the claim, quoted>
  cited: <the artifact>
  settled_by: local-package-cache | lockfile | network | none
  outcome: contradicted | confirmed | unverified
  finding: <the category you filed it under>   # only when contradicted
  blocked: <what stopped you>                  # only when unverified
~~~

A finding that rests on a premise you could not settle carries `confidence: low` and
says so in the block. **Never silently skip, never silently trust.**

Do **NOT** treat this as licence to leave the repo on any other question. Absent an
`### External premises` section, your evidence bar is unchanged.
```

The closing paragraph is the anti-derailment counterpart these bodies already carry for every other extension: a new permission to leave the repo is a new way to wander.

- [ ] **Step 7: Run everything**

Run: `bash scripts/validate.sh && bash scripts/validate.test.sh 2>&1 | tail -1`
Expected: `OK: all artifacts valid` then `pass=93 fail=0`

- [ ] **Step 8: Commit**

```bash
git add core/skills/ai-antipatterns/SKILL.md core/skills/correctness/SKILL.md core/skills/api-contract/SKILL.md core/agents/ai-antipatterns-reviewer.md core/agents/correctness-reviewer.md core/agents/api-contract-reviewer.md scripts/validate.sh scripts/validate.test.sh
git commit -m "feat: give three reviewers the external-premise contract (#13)"
```

---

### Task 4: The synthesis ledger

**Files:**
- Modify: `core/skills/review-pro-synthesize/SKILL.md`
- Modify: `scripts/validate.sh`
- Test: `scripts/validate.test.sh` (including `write_orchestrator`'s synthesize branch)

**Interfaces:**
- Consumes: the block field names from Task 3 (`premise`, `cited`, `settled_by`, `outcome`, `finding`, `blocked`) and `external_premises` from Task 2.
- Produces: the report section `### External premises`. Nothing consumes it; it is the delivery point.

- [ ] **Step 1: Update the synthesize fixture**

In `write_orchestrator`'s `review-pro-synthesize` branch, after the `Dedup the spec pool` line, add:

```
### External premises
```

- [ ] **Step 2: Write the failing test**

Insert before the summary block:

```bash
# Case AA: the synthesis ledger, without which a reviewer's "could not verify"
# statement never reaches the report the reader actually reads.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/review-pro-synthesize" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_orchestrator "$T/core/skills/review-pro-synthesize/SKILL.md" review-pro-synthesize
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"review-pro-synthesize","role":"orchestrator"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "external-premise ledger is gone"; then bad "ledger control fired on an intact fixture"; else ok "ledger control silent when present"; fi
grep -v '^### External premises$' "$T/core/skills/review-pro-synthesize/SKILL.md" > "$T/tmp" && mv "$T/tmp" "$T/core/skills/review-pro-synthesize/SKILL.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "external-premise ledger is gone"; then ok "removed ledger detected"; else bad "removed ledger not detected"; fi
rm -rf "$T"
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `bash scripts/validate.test.sh 2>&1 | tail -2`
Expected: `pass=94 fail=1`, failing on `removed ledger detected`.

- [ ] **Step 4: Add the guard**

Inside the existing `if [[ -f "$SYNTH_MD" ]]` block:

```bash
  grep -qF 'External premises' "$SYNTH_MD" \
    || add_error "review-pro-synthesize/SKILL.md: the external-premise ledger is gone - a reviewer's 'could not verify' statement dies before the report the reader actually reads"
```

- [ ] **Step 5: Run tests, confirm green, confirm the real repo is red**

Run: `bash scripts/validate.test.sh 2>&1 | tail -1`
Expected: `pass=95 fail=0`

Run: `bash scripts/validate.sh`
Expected: FAIL, one error, the ledger guard.

- [ ] **Step 6: Add the ledger to synthesis**

In `core/skills/review-pro-synthesize/SKILL.md`, after the `## Spec axis` section:

```markdown
## External premises

Triage's `external_premises` names claims the diff's rationale rests on that could not
be settled inside the repo. Each one comes back from its owning reviewer as a row in that
reviewer's `## Premise verification` block, whatever the outcome was. Print one table,
and omit the whole section when triage emitted no premises:

~~~
### External premises
| Premise | Cited | Settled by | Outcome |
~~~

Map the columns straight off the block: `Settled by` from `settled_by`, `Outcome` from
`outcome`, and for `unverified` append the reason from `blocked`, for `contradicted` the
category from `finding`.

List confirmed premises rather than dropping them. If a confirmed premise leaves no
trace, a reader cannot tell "checked and it held" from "never checked", and removing
that ambiguity is the whole purpose of the axis.

If triage reported a premise that appears in no reviewer's block, print the row with
outcome `not reported` and name the owner triage assigned. A premise that was routed and
then vanished is a reviewer contract violation, and it is the failure mode this feature
exists to prevent, so it must not be the quietest line in the report.

The out-of-diff evidence check needs no exception here. Its definition already counts an
upstream source as out-of-diff evidence, and these are code-axis findings, so a premise
finding satisfies the tripwire because the review genuinely left the diff.
```

- [ ] **Step 7: Run everything**

Run: `bash scripts/validate.sh && bash scripts/validate.test.sh 2>&1 | tail -1`
Expected: `OK: all artifacts valid` then `pass=95 fail=0`

- [ ] **Step 8: Commit**

```bash
git add core/skills/review-pro-synthesize/SKILL.md scripts/validate.sh scripts/validate.test.sh
git commit -m "feat: report external premises and their disposition (#13)"
```

---

### Task 5: The acceptance test

The guards prove a line is present. They do not prove the feature works. This task is the one that can fail for a real reason.

**Files:**
- Create: `studies/2026-08-copilot-pr-pilot/REPLAY-case2.md`

**Interfaces:**
- Consumes: everything from Tasks 1 through 4.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Establish whether case 2 can be replayed at all**

Read `studies/2026-08-copilot-pr-pilot/FINDINGS-case2.md` and check for the upstream repo, the PR or commit range, and the two package versions. Then:

```bash
gh pr view <the PR> --repo <the repo> --json headRefOid,baseRefOid,title,body 2>&1 | head -20
```

If the PR is reachable and the SHAs resolve, the replay is real. If not, say so in the report and build the synthetic fixture in Step 2b instead. Do not skip this quietly: a feature whose acceptance test was silently downgraded is a feature nobody has tested.

- [ ] **Step 2a: Replay it (preferred path)**

Clone the upstream repo at the base SHA, check out the head SHA, install this branch's build of review-pro, and run a review with **no hand-written mandate of any kind**. The whole of the test is that the mandate is gone.

Record: whether triage extracted the premise, which owner it assigned, which channel settled it, and whether the report's ledger names the premise. Success is the false premise surfacing on its own.

- [ ] **Step 2b: Synthetic fixture (only if 2a is impossible)**

Build a throwaway repo with a dependency bump whose commit message cites a specific upstream issue that demonstrably does not say what the message claims. Run the same review. State in the report that this is synthetic and therefore weaker evidence than a replay.

- [ ] **Step 3: Write the result down, including a negative one**

Create `studies/2026-08-copilot-pr-pilot/REPLAY-case2.md` with what was run, what the pipeline did at each stage, and the verdict against the issue's acceptance criterion: either a finding grounded in the artifact, or an explicit statement that it could not be verified. If the feature did not fire, that is the finding, and it goes in the file rather than into a retry loop.

- [ ] **Step 4: Commit**

```bash
git add studies/2026-08-copilot-pr-pilot/REPLAY-case2.md
git commit -m "test: replay pilot case 2 without a hand-written mandate (#13)"
```

---

### Task 6: Release 1.1.0

**Files:**
- Modify: `cli/package.json`, `.claude-plugin/marketplace.json` (two version fields), `core/.claude-plugin/plugin.json`, `core/.codex-plugin/plugin.json`
- Check: `docs/llms.txt`, `cli/README.md`, `README.md`

- [ ] **Step 1: Check the two surfaces that were missed last release**

Both were missed in 0.7.0 and neither is covered by an automated check:

```bash
grep -n "reviewer\|axis\|premise" docs/llms.txt
grep -n "reviewer\|axis" cli/README.md
```

`docs/llms.txt` is hand-written, so the site drift check never reads it. `cli/README.md` is what npm renders on the package page, and it sits outside `core/`. Decide for each whether the external-premise behaviour belongs in it. The reviewer count does not change, so the published-count guard is not involved.

- [ ] **Step 2: Bump all four manifests together**

```bash
grep -rn '"version"' cli/package.json .claude-plugin/marketplace.json core/.claude-plugin/plugin.json core/.codex-plugin/plugin.json
```

Set every one to `1.1.0`. The validator has a plugin-manifest version alignment check; a partial bump fails it.

- [ ] **Step 3: Run the full suite**

```bash
bash scripts/validate.sh && bash scripts/validate.test.sh 2>&1 | tail -1
```

```bash
cd cli && npm test && npx tsc --noEmit && npm run build
```

```bash
node scripts/build-site.js && git status --porcelain docs/
```

Expected: validator `OK`, meta-tests `pass=95 fail=0`, CLI `49 passed`, `tsc` clean, `docs/` showing no drift.

- [ ] **Step 4: Review this branch with review-pro itself before opening the PR**

Non-negotiable, and it has caught something on every release. Two known hazards from last time: a reviewer subagent can leave the working tree on another branch, so re-check `git branch --show-current` before trusting any verification run after a review; and ask one reviewer specifically about published artifacts, because the npm page and `llms.txt` have both gone stale unnoticed.

- [ ] **Step 5: Commit and open the PR**

```bash
git add -A
git commit -m "release: v1.1.0"
git push -u origin feat/external-premise-verification
```

---

## Self-Review

**Spec coverage.** Every spec section maps to a task: threshold and owner selection to Task 2 step 6; channel order to Task 1; routing split to Task 2 step 6; plan field to Task 2 step 6; assign-dispatches to Task 2; triage-does-not-verify to Task 2; cap to Task 2; reaching the reviewer to Task 2 step 7; contradicted, unverifiable, and the confidence rule to Task 3; the ledger and the tripwire note to Task 4; the eight guards spread across Tasks 1 through 4; the acceptance test to Task 5; published surfaces and the version to Task 6.

**One spec item is deliberately not implemented as written.** The spec's guard table has eight rows and its prose said "seven guards" on the first pass; the orchestrator row was added after a sandbox run showed nothing failed when that line was deleted. The spec has been corrected. If a future reader finds the two disagreeing, the table is right.

**Verified rather than asserted.** Every command and code block in Tasks 1 through 4 was executed against a copy of this repo before being written here. The measured results: the eight guards produce 17 errors on an unmodified `core/`; neutralizing any one guard turns exactly its own case or cases red (one each for the five single-file guards, two each for the two owner-side guards spanning a rubric and a body); the fixture update is required for exactly one case (Case A), not the eleven a first reading of `write_orchestrator`'s call sites suggests; and the suite lands at `pass=95 fail=0`.

**The step-by-step assertion counts in Tasks 1 through 4 assume the tasks run in order.** Out of order, the intermediate `pass=NN` numbers shift while the final 93 does not.
