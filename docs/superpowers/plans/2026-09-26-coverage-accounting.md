# Coverage Accounting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every review report states which changed files its code reviewers examined, labelled self-reported, and separately which files no reviewer was sent.

**Architecture:** Code reviewers append a `## Files examined` block (not a finding). Synthesis combines those blocks with the dispatch plan's per-reviewer `context.changed_files` into one coverage line placed between the Spec and Verification lines. The validator pins every load-bearing sentence in every copy (ADR-0001), each pin with its own mutation test.

**Tech Stack:** Markdown skills and agent bodies, bash + python3 validator (`scripts/validate.sh`), bash meta-tests (`scripts/validate.test.sh`), vitest for the CLI (`cd cli && npm test`).

**Spec:** `docs/superpowers/specs/2026-09-26-coverage-accounting-design.md`

## Global Constraints

- Everything written to the repo is English. No em dash (U+2014) in any new or edited line.
- v1.0 contract is frozen: additions only, optional, backward compatible. No existing field changes meaning.
- The coverage signal never changes a finding, a severity, or the verdict.
- Agent bodies are embedded verbatim in a TOML basic multi-line string on Codex: new body text must contain no `"""` and no backslash.
- The spec reviewer emits no block and is never a receiver.
- The coverage line text is exactly `Coverage (self-reported): <e> of <n> changed files examined by at least one reviewer[, <x> not examined][, <u> not reported][, <s> sent to no reviewer].`
- Report header order: Spec line, Coverage line, Verification line, out-of-diff caveat, External premises.
- Never reference a synthesis step by number (the validator rejects `step N` / `rule N` in the synthesis skill).
- Read validator and test output in full; never pipe it through `tail`.

## Review Focus

1. A reviewer from an older install returns no block: the file must render `not reported` and the reviewer must be named, never counted as examined. Pinned by the "never rendered as examined" and "no Files examined block from" checks (Task 2).
2. The inline path (skills-only install, no subagents): the orchestrator must emit the block for inline reviews from its own skill text, since `shared/` may be absent. Pinned by the orchestrator `exactly once` check (Task 3).
3. Codex install: a backslash or `"""` in new body text breaks the TOML. Checked by the grep in Task 1 Step 6.
4. The orchestrator narrowing a reviewer's files below its plan list would make the deterministic layer blind. Pinned by the `this reviewer's \`context.changed_files\`` check (Task 3).
5. Two report templates (orchestrator and synthesis) drifting apart on the Coverage line or its position. Pinned by the order check applied to both files (Tasks 2 and 3).

---

### Task 1: The reviewer block (12 code reviewer bodies + shared schema)

**Files:**
- Modify: `core/agents/{a11y,ai-antipatterns,api-contract,backend,correctness,craft,db,dry,frontend,performance,security,tests}-reviewer.md`
- Modify: `core/shared/output-schema.md` (append a section)
- Modify: `scripts/validate.sh` (after the BODY_INVARIANTS loop)
- Test: `scripts/validate.test.sh` (fixture `write_good_agent_body`, new Case AR)

**Interfaces:**
- Produces: the block format below, the heading `## Files examined`, fields `examined`, `not_examined`, `file`, `reason`. Tasks 2 and 3 consume these exact names.

- [ ] **Step 1: Write the failing tests.** In `write_good_agent_body`, before `EOFB`, append:

```
## Files examined
Account for every file exactly once; a list that overstates what you read is wrong.
## Final reminder
Findings or the none-line, followed by your \`## Files examined\` block.
```

Append Case AR after Case AQ (before the final `echo "---"`):

```bash
# Case AR: the Files examined block in every code reviewer body. The body is what the
# running subagent obeys (ADR-0001), and the Final reminder is its terminal restatement:
# a reminder that says "findings or the none-line" and nothing else invites dropping the block.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/spec" "$T/core/agents" "$T/core/shared"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_good_reviewer "$T/core/skills/spec/SKILL.md"
printf 'never exceeds Medium. `line` is `0` when there is no such hunk.\nabstained (no spec text)\n' >> "$T/core/skills/spec/SKILL.md"
write_good_spec_body "$T/core/agents/spec-reviewer.md"
printf '{ "skills": [{"name":"security","role":"reviewer"},{"name":"spec","role":"reviewer"}], "agents": [{"name":"security-reviewer","loads_skill":"security"},{"name":"spec-reviewer","loads_skill":"spec"}] }\n' > "$T/manifest.json"
w_body(){ write_good_agent_body "$1" security-reviewer; }
w_schema(){ printf '# Schema\nevidence_refs\nsame evidence bar\n## Files examined\nEvery file appears exactly once.\n' > "$1"; }
w_body "$T/core/agents/security-reviewer.md"; w_schema "$T/core/shared/output-schema.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "^FAIL: "; then bad "files-examined control: fired on an intact tree (the spec body carries no block, by design)"; else ok "files-examined control: silent on an intact tree, spec body exempt"; fi
B="$T/core/agents/security-reviewer.md"
stage_mutation "$B" w_body "no '## Files examined' block"          "body files-examined heading"   grep -vxF '## Files examined'
stage_mutation "$B" w_body "the exactly-once rule is gone"         "body exactly-once rule"        sed 's/exactly once/once/'
stage_mutation "$B" w_body "the overstating rule is gone"          "body overstating rule"         sed 's/overstates what you read/is too long/'
stage_mutation "$B" w_body "Final reminder does not name"          "body final reminder"           sed 's/followed by your .## Files examined. block/and nothing else/'
w_body "$B"
stage_mutation "$T/core/shared/output-schema.md" w_schema "output-schema.md: the Files examined block is gone" "schema files-examined block" grep -vxF '## Files examined'
stage_mutation "$T/core/shared/output-schema.md" w_schema "output-schema.md: the Files examined block is gone" "schema exactly-once rule"    sed 's/exactly once/once/'
rm -rf "$T"
```

- [ ] **Step 2: Run the tests to verify the new ones fail.** Run `bash scripts/validate.test.sh`. Expected: the four `body ...` and two `schema ...` mutation cases report `NOT detected`, everything else passes.

- [ ] **Step 3: Add the validator checks** after the BODY_INVARIANTS loop in `scripts/validate.sh`:

```bash
# Coverage accounting (ADR-0010). Every code reviewer accounts for each file it received
# in a `## Files examined` block. The spec reviewer is exempt: coverage measures reading
# for defects, and synthesis never counts it as a receiver. The Final reminder check is
# scoped to that section because it is the restatement a reviewer obeys last.
for body in "$ROOT"/core/agents/*-reviewer.md; do
  [[ -f "$body" ]] || continue
  [[ "$(fm_get "$body" "loads_skill")" == "spec" ]] && continue
  b="$(basename "$body")"
  grep -qxF '## Files examined' "$body" \
    || add_error "$b: no '## Files examined' block - an empty review and an unread file look the same in the report"
  grep -qF 'exactly once' "$body" \
    || add_error "$b: the exactly-once rule is gone - a reviewer can leave files out of its declaration and they read as covered"
  grep -qF 'overstates what you read' "$body" \
    || add_error "$b: the overstating rule is gone - nothing tells the reviewer a complete-looking list is the wrong answer"
  awk '/^## Final reminder/{s=1;next} s&&/^## /{exit} s' "$body" | grep -qF '## Files examined' \
    || add_error "$b: the Final reminder does not name the '## Files examined' block - its terminal restatement tells the reviewer to return findings only"
done
if [[ -f "$SCHEMA_DOC" ]]; then
  { grep -qxF '## Files examined' "$SCHEMA_DOC" && grep -qF 'exactly once' "$SCHEMA_DOC"; } \
    || add_error "core/shared/output-schema.md: the Files examined block is gone - rubric readers and the inline path lose the coverage contract"
fi
```

- [ ] **Step 4: Edit the 12 bodies** with a script that asserts every replacement hits exactly once per file (so a body whose wording differs fails loudly instead of being skipped):
  - Mandate: insert ` Every answer ends with your \`## Files examined\` block.` before ` You are not a general assistant.`
  - Work step 4, plain bodies: `` ` and stop.`` at the end of the `4.` line becomes `` `. Either way, append your `## Files examined` block (see below) and stop.``
  - Work step 4, premise bodies (ai-antipatterns, api-contract, correctness): `Stop after that.` becomes `Then append your \`## Files examined\` block (see below), which is not a finding either. Stop after that.`
  - Final reminder, plain bodies: `` ` line. Echoing`` becomes `` ` line, followed by your `## Files examined` block. Echoing``
  - Final reminder, premise bodies: `section. Echoing` becomes `section, and always your \`## Files examined\` block. Echoing`
  - Insert this section immediately before `## Final reminder`:

````
## Files examined

After your findings or your none-line, always append one block that accounts for every file under `### Changed file contents`, each **exactly once**, in one of two lists:

```
## Files examined
examined: [<path>, ...]
not_examined:
  - file: <path>
    reason: <why, one line>
```

- A file is examined only if you read its diff or its contents while applying your skill. A file you know only from the list or from a `--stat` is not examined.
- Any reason is acceptable: outside your concern, generated data, not reached. A missing entry is not. Write an empty list as `[]`.
- An accurate list with gaps is the correct answer. A complete-looking list that overstates what you read is the wrong one: synthesis reports your list as the review's coverage, and nothing downstream can check it.
- The block is not a finding. It never replaces the none-line, and the none-line never replaces it.

````

- [ ] **Step 5: Append to `core/shared/output-schema.md`:**

````
## Files examined

Not a finding. After its findings or its none-line, every code reviewer appends one block. The spec reviewer does not: coverage measures reading for defects, and matching a file against a requirement is not that.

```
## Files examined
examined: [<path>, ...]
not_examined:
  - file: <path>
    reason: <why, one line>
```

- Every file the reviewer received under `### Changed file contents` appears **exactly once**, in one of the two lists. An empty list is `[]`.
- Examined means the reviewer read the file's diff or contents while applying its rubric. A file known only from the list or from a `--stat` is not examined.
- Any reason is acceptable; a missing entry is not.
- An accurate list with gaps is correct; a complete-looking list that overstates what was read is wrong.
- Synthesis turns these blocks into the report's coverage line, labelled self-reported. The block never changes a finding.
````

- [ ] **Step 6: Run everything.** `./scripts/validate.sh` (expect `OK: all artifacts valid`), `bash scripts/validate.test.sh` (expect `fail=0`), and `grep -nF '"""' core/agents/*.md; grep -nF '\\' core/agents/*-reviewer.md` (expect no new hits from this task's text).

- [ ] **Step 7: Commit** `feat(reviewers): account for every changed file in a Files examined block`.

### Task 2: Synthesis computes and renders coverage

**Files:**
- Modify: `core/skills/review-pro-synthesize/SKILL.md` (intro inputs, Steps, new `## Coverage` section after `## Out-of-diff evidence check`, Output template)
- Modify: `core/agents/review-pro-synthesize-subagent.md` (Work step 1)
- Modify: `scripts/validate.sh` (synthesis required sections; coverage pins; template order; subagent body)
- Test: `scripts/validate.test.sh` (fixture `w_synth`, new Case AS)

**Interfaces:**
- Consumes: block heading and fields from Task 1.
- Produces: the coverage line text (Global Constraints), the section `## Coverage`, the phrases pinned below. Task 3 copies the line into the orchestrator template.

- [ ] **Step 1: Write the failing tests.** Add to the `review-pro-synthesize` fixture in `write_stage_skill`, right after the `## Out-of-diff evidence check` block:

```
## Coverage
The spec reviewer is not a receiver.
A missing report is never rendered as examined.
Print `no Files examined block from: <reviewers>`.
Print `contradiction: <reviewer> filed a finding in <file> and declared it not examined`.
Caveat: changed files were sent to no reviewer.
With `diff_class: trivial`, omit the coverage line.
It never changes a finding, a severity, or the verdict.
```

and replace the fixture's final `## Output` line with:

```
## Output
Spec: measured against <ref>
Coverage (self-reported): <e> of <n> changed files examined by at least one reviewer.
Verification: <N> checked
```

Append Case AS:

```bash
# Case AS: synthesis's coverage contract (ADR-0010). Each pin is one sentence whose
# loss changes what the report claims about files nobody read.
stage_fixture review-pro-synthesize orchestrator w_synth; SYN="$STAGE"
stage_mutation "$SYN" w_synth "missing section '## Coverage'"          "synthesis coverage section"         sed 's/^## Coverage$/## Files read/'
stage_mutation "$SYN" w_synth "the spec exclusion is gone"             "synthesis coverage spec exclusion"  grep -vF 'The spec reviewer is not a receiver'
stage_mutation "$SYN" w_synth "the not-reported rule is gone"          "synthesis coverage not-reported"    grep -vF 'never rendered as examined'
stage_mutation "$SYN" w_synth "the missing-block line is gone"         "synthesis coverage missing block"   grep -vF 'no Files examined block from'
stage_mutation "$SYN" w_synth "the contradiction line is gone"         "synthesis coverage contradiction"   grep -vF 'declared it not examined'
stage_mutation "$SYN" w_synth "the sent-to-no-reviewer caveat is gone" "synthesis coverage deterministic"   grep -vF 'sent to no reviewer'
stage_mutation "$SYN" w_synth "the trivial rule is gone"               "synthesis coverage trivial"         grep -vF 'diff_class: trivial'
stage_mutation "$SYN" w_synth "the no-effect rule is gone"             "synthesis coverage no-effect"       grep -vF 'never changes a finding'
stage_mutation "$SYN" w_synth "Output template has no coverage line"   "synthesis template coverage line"   grep -vF 'Coverage (self-reported):'
stage_mutation "$SYN" w_synth "Output template orders"                 "synthesis template order"           sed -e 's/^Spec: measured against <ref>$/@@S@@/' -e 's/^Verification: <N> checked$/Spec: measured against <ref>/' -e 's/^@@S@@$/Verification: <N> checked/'
rm -rf "$T"

# Case AT: the synthesis subagent body must name both coverage inputs, or subagent
# synthesis renders every file not reported.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
w_ssub(){ printf -- '---\nname: review-pro-synthesize-subagent\ndescription: s\nloads_skill: security\nskills: [security]\n---\nReceive each `## Files examined` block and each reviewer'"'"'s `context.changed_files`.\n' > "$1"; }
w_ssub "$T/core/agents/review-pro-synthesize-subagent.md"
printf '{ "skills": [{"name":"security","role":"reviewer"}], "agents": [{"name":"review-pro-synthesize-subagent","loads_skill":"security"}] }\n' > "$T/manifest.json"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "^FAIL: "; then bad "synthesis subagent control: fired on an intact body"; else ok "synthesis subagent control: silent on an intact body"; fi
stage_mutation "$T/core/agents/review-pro-synthesize-subagent.md" w_ssub "the coverage inputs are gone" "synthesis subagent blocks input" sed 's/`## Files examined` block/finding/'
stage_mutation "$T/core/agents/review-pro-synthesize-subagent.md" w_ssub "the coverage inputs are gone" "synthesis subagent lists input"  sed 's/`context.changed_files`/plan/'
rm -rf "$T"
```

- [ ] **Step 2: Run** `bash scripts/validate.test.sh`; expect the Case AS and AT mutations `NOT detected` (and the AS control may fire on the missing section until Step 3).

- [ ] **Step 3: Validator.** Add `## Coverage` to the `review-pro-synthesize` req list after `## Out-of-diff evidence check`. Add, inside a `[[ -f "$SYNTH_MD" ]]` block:

```bash
# Coverage accounting (ADR-0010). Scoped to the section, because several of these
# phrases would survive elsewhere in the file after the section that gives them meaning is gone.
COV="$(awk '/^## Coverage$/{s=1;next} s&&/^## /{exit} s' "$SYNTH_MD")"
# An absent section is reported once by the required-section check; pinning its phrases
# too would turn one deletion into eight errors.
cov_pin(){ [[ -n "$COV" ]] || return 0; printf '%s\n' "$COV" | grep -qF "$1" || add_error "review-pro-synthesize/SKILL.md: $2"; }
cov_pin 'The spec reviewer is not a receiver' "the spec exclusion is gone from ## Coverage - a file only the spec reviewer read would show as examined"
cov_pin 'never rendered as examined'          "the not-reported rule is gone from ## Coverage - a reviewer that returned nothing would read as full coverage"
cov_pin 'no Files examined block from'        "the missing-block line is gone from ## Coverage - a reviewer contract violation becomes the quietest line in the report"
cov_pin 'declared it not examined'            "the contradiction line is gone from ## Coverage - a finding in a file its reviewer called unread goes unnoticed"
cov_pin 'sent to no reviewer'                 "the sent-to-no-reviewer caveat is gone from ## Coverage - a narrowed dispatch is never reported"
cov_pin 'diff_class: trivial'                 "the trivial rule is gone from ## Coverage - every one-line chore gets a coverage line and readers learn to skip it"
cov_pin 'never changes a finding'             "the no-effect rule is gone from ## Coverage - coverage could start gating findings or the verdict"
```

and a template check usable by both skills (Task 3 reuses it):

```bash
# The report header order is Spec, Coverage, Verification (ADR-0010). Checked inside the
# Output section of both copies of the template, because the orchestrator carries one too.
check_header_order(){
  local f="$1" label="$2" out s c v
  # No Output section at all is its own failure (a required section for synthesis);
  # the order question only exists once there is a template to order.
  grep -qxF '## Output' "$f" || return 0
  out="$(awk '/^## Output$/{s=1;next} s&&/^## [A-Z]/&&!/^## Verdict/&&!/^## Spec \(/{exit} s' "$f")"
  c=$(printf '%s\n' "$out" | grep -nF 'Coverage (self-reported):' | head -1 | cut -d: -f1)
  if [[ -z "$c" ]]; then add_error "$label: the Output template has no coverage line - the report would drop the coverage signal"; return; fi
  s=$(printf '%s\n' "$out" | grep -nF 'Spec: measured against' | head -1 | cut -d: -f1)
  v=$(printf '%s\n' "$out" | grep -nF 'Verification: <N> checked' | head -1 | cut -d: -f1)
  if [[ -n "$s" && -n "$v" ]] && ! [[ "$s" -lt "$c" && "$c" -lt "$v" ]]; then
    add_error "$label: the Output template orders the header lines wrong - it must be Spec, Coverage, Verification"
  fi
}
check_header_order "$SYNTH_MD" "review-pro-synthesize/SKILL.md"
```

Synthesis subagent body:

```bash
SSUB="$ROOT/core/agents/review-pro-synthesize-subagent.md"
if [[ -f "$SSUB" ]]; then
  { grep -qF '`## Files examined` block' "$SSUB" && grep -qF '`context.changed_files`' "$SSUB"; } \
    || add_error "review-pro-synthesize-subagent.md: the coverage inputs are gone - subagent synthesis would report every file not reported"
fi
```

- [ ] **Step 4: Write the synthesis text.** Intro input list gains `each dispatched reviewer's \`context.changed_files\``. Steps: **Collect** also sets aside each code reviewer's `## Files examined` block for **Coverage** (never deduped). Insert a step after **Out-of-diff evidence check**: `**Coverage** (see below): which changed files the review read, from the dispatch plan and the reviewers' own declarations. Review-level, never a gate.` Insert the section:

````
## Coverage

Which changed files the review read, from two sources that must never be confused: the dispatch plan, which says what each reviewer received, and each code reviewer's `## Files examined` block, which says what it read. The second is a statement, not evidence, and the report labels it self-reported every time.

Inputs: triage's `changed_files` and `diff_class`, each dispatched reviewer's `context.changed_files` from the dispatch plan, the code reviewers' `## Files examined` blocks, and the merged findings. **The spec reviewer is not a receiver**: it reads a file to match it against a requirement, not for defects, and counting it would show a file no code reviewer opened as examined. The receivers of a file are the dispatched code reviewers whose `context.changed_files` contains it.

Put each file in `changed_files` in exactly one state, checked in this order:

| State | Condition |
|---|---|
| sent to no reviewer | it has no receiver |
| examined | a receiver lists it under `examined`, or filed a finding in it |
| not examined | every receiver lists it under `not_examined` |
| not reported | anything else: some receiver gave no entry for it |

- A finding filed in a file counts as its reviewer examining that file, whatever the block says, and a refuted finding counts too: it shows the file was read, not that the finding holds. When the same reviewer also listed the file under `not_examined`, print `contradiction: <reviewer> filed a finding in <file> and declared it not examined`.
- A reviewer that returned no block, a block that leaves a file out, and a file listed in both of one reviewer's lists all leave that reviewer with no entry for the file. **A missing report is never rendered as examined.** Whenever any receiver returned no block, print `no Files examined block from: <reviewers>`, even when other reviewers examined every file it received.

Print the coverage line directly under the Spec line and above the Verification line:

```
Coverage (self-reported): <e> of <n> changed files examined by at least one reviewer[, <x> not examined][, <u> not reported][, <s> sent to no reviewer].
```

- Under it, one indented detail line per file in the `not examined` and `not reported` states: `not examined: <file> (<reviewer>: <reason>; ...)`, `not reported: <file> (<silent reviewers>)`. When a state holds more than 10 files, collapse each directory (its first two path segments) holding more than 3 of them into one line with a count and at most three distinct reasons, and list the rest by name.
- Files sent to no reviewer also get this caveat under the detail lines, on every `diff_class`, because nothing reviewed them and that does not rest on anyone's word:

  ```
  > <s> changed files were sent to no reviewer, so nothing reviewed them: <files>.
  ```

- Never write verified, confirmed, complete or full on this line. "By at least one reviewer" is the claim, and it is a claim about files, not about every axis.
- Declared skips are listed, never warned about. A reason is the reviewer's own words and the reader judges it: skipping study data or design prose is usually right.

Rules:
- It **never changes a finding**, a severity, or the verdict. It is review-level, like the out-of-diff check.
- With `diff_class: trivial`, omit the coverage line and its detail lines: the whole change fits on a screen. The sent-to-no-reviewer caveat still prints.
- If `changed_files` or the per-reviewer `context.changed_files` lists are missing from your input, print `Coverage: not computed, <what> missing from the input.` and do not guess.
````

Output template: insert after the Spec lines:

```
Coverage (self-reported): <e> of <n> changed files examined by at least one reviewer[, <x> not examined][, <u> not reported][, <s> sent to no reviewer].
  not examined: <file> (<reviewer>: <reason>)
```

- [ ] **Step 5: Synthesis subagent body** Work step 1 names `each code reviewer's \`## Files examined\` block` and `each dispatched reviewer's \`context.changed_files\``, with `changed_files` and the per-reviewer lists "for **Coverage**".

- [ ] **Step 6: Run** `./scripts/validate.sh` and `bash scripts/validate.test.sh`, read in full. Expect OK and `fail=0`.

- [ ] **Step 7: Commit** `feat(synthesis): report self-reported coverage and files sent to no reviewer`.

### Task 3: Orchestrator and triage

**Files:**
- Modify: `core/skills/review-pro/SKILL.md` (step 3 items 2 and 3, inline paragraph, step 4 inputs, Output template)
- Modify: `core/skills/review-pro-triage/SKILL.md` (step 8, dispatch format comment)
- Modify: `scripts/validate.sh`, `scripts/validate.test.sh` (fixtures `w_orch`, triage fixture, new Case AU)

**Interfaces:**
- Consumes: block format (Task 1), coverage line and `check_header_order` (Task 2).

- [ ] **Step 1: Failing tests.** Add to the `review-pro` fixture:

```
`### Changed file contents`: the files in this reviewer's `context.changed_files`, all of them.
Every inline code review ends with the `## Files examined` block, each file exactly once.
## Output
Spec: measured against <ref>
Coverage (self-reported): <e> of <n> changed files examined by at least one reviewer.
Verification: <N> checked
```

Add to the triage fixture: `  changed_files: [a]   # Stage 3's coverage check compares against it`.

Case AU:

```bash
# Case AU: the orchestrator's half of coverage (ADR-0010). Without the plan-list rule the
# orchestrator can hand a reviewer fewer files than the plan shows and the deterministic
# layer never sees it; without the inline block a skills-only install reports nothing.
stage_fixture review-pro orchestrator w_orch; ORC="$STAGE"
stage_mutation "$ORC" w_orch "hands reviewers something other than their plan list" "orchestrator plan list"     sed "s/this reviewer's \`context.changed_files\`/the relevant files/"
stage_mutation "$ORC" w_orch "inline reviews no longer end with the Files examined block" "orchestrator inline block" grep -vF 'exactly once'
stage_mutation "$ORC" w_orch "Output template has no coverage line" "orchestrator template coverage line" grep -vF 'Coverage (self-reported):'
stage_mutation "$ORC" w_orch "Output template orders" "orchestrator template order" sed -e 's/^Spec: measured against <ref>$/@@S@@/' -e 's/^Verification: <N> checked$/Spec: measured against <ref>/' -e 's/^@@S@@$/Verification: <N> checked/'
rm -rf "$T"
stage_fixture review-pro-triage orchestrator write_stage_skill; TRI="$STAGE"
w_tri(){ write_stage_skill "$1"; }
stage_mutation "$TRI" w_tri "the coverage comparison is gone" "triage coverage comparison" grep -vF "coverage check compares against it"
rm -rf "$T"
```

- [ ] **Step 2: Run** the tests; expect the AU mutations `NOT detected`.

- [ ] **Step 3: Validator**, in the `ORCH_MD` block:

```bash
  grep -qF "this reviewer's \`context.changed_files\`" "$ORCH_MD" \
    || add_error "review-pro/SKILL.md: step 3 hands reviewers something other than their plan list - a narrowed prompt is invisible to the coverage check"
  { grep -qF '## Files examined' "$ORCH_MD" && grep -qF 'exactly once' "$ORCH_MD"; } \
    || add_error "review-pro/SKILL.md: inline reviews no longer end with the Files examined block - a skills-only install reports no coverage"
  check_header_order "$ORCH_MD" "review-pro/SKILL.md"
```

and in the `TRIAGE_MD` block:

```bash
  grep -qF 'coverage check compares against it' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: the coverage comparison is gone - nothing says the per-reviewer lists are what Stage 3 measures"
```

`check_header_order` must be defined before the ORCH_MD block runs; define it next to `add_error`.

- [ ] **Step 4: Edit the orchestrator.**
  - Step 3 item 2, `### Changed file contents`: `the files in this reviewer's \`context.changed_files\` from the dispatch plan, all of them. Handing a reviewer fewer files than its plan lists is a narrowing the coverage check cannot see.`
  - Step 3 item 3: collect also the `## Files examined` block; "Neither block is a finding".
  - Inline paragraph: append the block, the exactly-once rule, the examined definition, the overstating rule, and "The spec reviewer emits no block."
  - Step 4: the triage values passed to synthesis gain `each reviewer's \`context.changed_files\` from the dispatch plan`.
  - Output template: the coverage line after the Spec lines.

- [ ] **Step 5: Edit triage.** Step 8 gains: `List every file you hand each reviewer in its \`context.changed_files\`; the orchestrator hands exactly that list, and a file on no code reviewer's list is reported as sent to no reviewer.` Dispatch format: `changed_files: [<paths>]   # exactly what the orchestrator hands this reviewer; Stage 3's coverage check compares against it`.

- [ ] **Step 6: Run** validator, meta-tests and `cd cli && npm test`. All green, read in full.

- [ ] **Step 7: Commit** `feat(orchestrator): hand each reviewer its plan list and carry coverage inline`.

### Task 4: ADR, published surfaces, maintainer docs, roadmap

**Files:**
- Create: `docs/internals/adr/0010-report-coverage-as-self-reported.md`
- Modify: `README.md` (Synthesis bullet, example report), `docs/llms.txt`, `cli/README.md`, `docs/internals/glossary.md`, `docs/internals/reviewer-directive.md` (Final reminder description), `docs/superpowers/plans/2026-09-26-ocr-lessons-roadmap.md` (add to git; item 1 Status)

- [ ] **Step 1:** Write ADR-0010 (Context: the gap and the spike; Decision: two layers, the declared one always labelled self-reported, file-level, code axis only, review-level only; Rejected: file-by-axis matrix, counting spec, a warning threshold, transcript checks, a blocking missing block; Consequences: cost ~1 line per file per reviewer; what would revisit it).
- [ ] **Step 2:** README example report gains `Coverage (self-reported): 7 of 7 changed files examined by at least one reviewer.` between Spec and Verification; the Synthesis bullet gains one clause. `docs/llms.txt` and `cli/README.md` gain one clause each. Glossary gains **coverage**. reviewer-directive.md's Final reminder item names the block.
- [ ] **Step 3:** Site check: `grep -n -i "verif\|coverage" docs-src/i18n/en.json docs-src/*.html`. The site does not describe the report's header lines (it does not mention verification either), so no site change; run `node scripts/build-site.js` anyway and confirm `git status` shows no generated diff.
- [ ] **Step 4:** Roadmap item 1 Status: `done in this PR (feat/coverage-accounting); measured in studies/2026-09-coverage-spike`. `git add` the roadmap.
- [ ] **Step 5:** Run validator, meta-tests, CLI tests in full. Commit `docs: ADR-0010 and published surfaces for coverage accounting`.

### Task 5: Dogfood review

- [ ] Run review-pro on the branch (triage, reviewers as subagents, verification, synthesis). Ask one reviewer explicitly about published surfaces (README, llms.txt, cli README and package description, site, ADR index).
- [ ] For every fix, ask: did it remove the problem or move it? Re-run all three suites after each round.
- [ ] Open the PR (do not merge) with the measurement, decisions, rejected alternatives, and what was not verified.

---

## Execution notes (2026-09-26)

Tasks 1 to 4 ran as written, except where a ruling says otherwise. The branch's own review (Task 5) changed the design in three places, all reflected in the spec:

- The orchestrator no longer carries a copy of the report template. Its `## Output` points at the synthesis skill's, because the copy had already lost the coverage detail line (round 1). The `check_header_order` helper planned for both files became a single check on the synthesis template.
- The orchestrator's reviewer prompt carries a `### Files examined` reminder with the format and the honesty rule, so agents installed before this release still emit an honest block (rounds 1 and 2).
- The block's keys are held in `validate.sh` as one canonical text instead of per-key pins, and prose rules are pinned on their own line (round 2), because phrase pins kept being satisfied by another line in the same file.
