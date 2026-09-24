# Refuting Verifier Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Stage 3b to review-pro in which one fresh agent per Medium+ code finding tries to refute it from source, and make synthesis apply the results asymmetrically: a refuted Medium leaves the verdict, a refuted High or Critical keeps blocking and is marked disputed.

**Architecture:** A new pipeline-stage skill (`review-pro-verify`) and its subagent body. The orchestrator runs synthesis's merge steps, dispatches the verifiers in parallel, then hands the results to the rest of synthesis. Everything is markdown instructions guarded by `scripts/validate.sh` and its meta-tests. The only TypeScript is new vitest coverage; `cli/src` does not change.

**Tech Stack:** Markdown skills and agent bodies, bash (`scripts/validate.sh`, `scripts/validate.test.sh`), Python 3 snippets inside the validator, TypeScript + vitest in `cli/`.

**Spec:** `docs/superpowers/specs/2026-09-24-refuting-verifier-design.md`. Evidence: `studies/2026-09-refuting-verifier/`.

## Global Constraints

- No em dash, middle dot (`·`) or arrow character (`→`) in any text this plan adds. Existing lines that already contain them are left alone.
- Selection: code-axis findings at Medium, High or Critical; severity order, then file and line; at most **8** per review.
- Spec-axis findings are never verified in v1, and the report says so.
- A refuted Medium leaves the verdict. A refuted High or Critical keeps blocking and is marked `disputed`.
- `partly_refuted` never changes severity.
- Not verified is never rendered as verified or standing. Reasons: `cap`, `error`, `no independent verifier`.
- Agreement ("flagged by N reviewers") never protects a refuted finding, and the count is never sent to a verifier.
- The orchestrator never verifies a finding in its own context.
- The verifier is not added to `ORCHESTRATOR_SKILLS` in `cli/src/lib/plugin.ts`, so Codex installs it as a real subagent.
- The finding schema (`core/shared/output-schema.md`) does not change.
- No release is cut by this plan.
- Meta-test baseline: `bash scripts/validate.test.sh` prints `pass=131 fail=0` before Task 1.

## Review Focus

1. **A finding whose severity conflict resolution raises after selection.** If verification ran before conflict resolution, a Low the owner raises to Medium would never be selected and could render as checked. Expected: selection runs after conflict resolution. Pinned by the step-order guard in Task 4.
2. **A verifier reply that is malformed.** Two blocks, a `finding` key that binds to no finding, or an inconsistent `defect_stands`. Expected: that finding is `not verified (error)` and nothing else changes. Pinned by the render check in Task 8.
3. **Synthesis running as a subagent with no verification results.** Expected: every Medium+ code finding is `not verified (no independent verifier)`, the verdict is computed as today. Pinned by the render check's second input in Task 8.
4. **A finding in a file the diff deletes.** The working tree no longer has it. Expected: the verifier reads it from the base with `git show <base>:<path>`, so the orchestrator must name the base. Pinned by the `git show <base>:` guard in Task 1 and the `base:` line guard in Task 3.
5. **A change description that asserts the finding is wrong.** A PR body is the author's claim. Expected: it never counts as a citation. Pinned by the `never settles a claim` guard in Task 1, and exercised by V07 in Task 6, whose change description carries the false rationale the finding refutes.

---

### Task 1: Amend the spec for what exploration found

Two things the spec says do not survive contact with the code.

- `tools:` in agent frontmatter. No agent body in `core/agents/` declares it, and opencode copies the same `.md` file verbatim and reads `tools` as a map, so a Claude Code style comma list risks breaking the agent on opencode. The verifier body declares no `tools:`; read-only rests on the prompt everywhere and on `sandbox_mode = "read-only"` on Codex.
- Placement. Synthesis today resolves conflicts after dedup and weight. If verification ran before that, a finding the owner raises to Medium would never be selected (Review Focus 1). Verification moves to after conflict resolution; the spec's "after dedup, before calibration and verdict" still holds.

**Files:**
- Modify: `docs/superpowers/specs/2026-09-24-refuting-verifier-design.md`

- [ ] **Step 1: Replace the tools paragraph**

In the spec, replace:

```
Tools: Read, Grep, Glob, Bash and WebFetch; no Edit or Write. "Do not build, run the
project or install packages" stays in the prompt, since no portable mechanism
restricts Bash per command. On Codex the installed agent is `sandbox_mode = "read-only"`.
```

with:

```
Tools: the body declares no `tools:` field. No other agent body does, and opencode
copies the same file verbatim and reads `tools` as a map, so a comma list written for
Claude Code could break the agent there. Read-only rests on the prompt ("do not modify
the working tree, do not build or run the project, do not install packages") on every
target, and on `sandbox_mode = "read-only"` on Codex, where the CLI sets it for every
installed agent.
```

- [ ] **Step 2: Move verification after conflict resolution**

In the spec, replace:

```
- **3a Merge.** Unchanged: collect, partition into code and spec pools, dedup, weight.
```

with:

```
- **3a Merge.** Unchanged: collect, partition into code and spec pools, dedup, weight,
  resolve conflicts by ownership. Conflict resolution comes before selection because it
  can raise a finding to Medium, and a finding raised after selection would never be
  verified.
```

- [ ] **Step 3: Check and commit**

Run: `grep -c -E '—|·|→' docs/superpowers/specs/2026-09-24-refuting-verifier-design.md`
Expected: `0`

```bash
git add docs/superpowers/specs/2026-09-24-refuting-verifier-design.md
git commit -m "docs(spec): no tools field on the verifier body; verify after conflict resolution

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: The verifier skill, its agent body, and their guards

**Files:**
- Create: `core/skills/review-pro-verify/SKILL.md`
- Create: `core/agents/review-pro-verify-subagent.md`
- Modify: `manifest.json` (skills and agents arrays)
- Modify: `scripts/validate.sh:9` (`ORCHESTRATORS`), `scripts/validate.sh:68-71` (per-stage `req` case), and the load-bearing rules block after the `SYNTH_MD` checks (around line 196)
- Test: `scripts/validate.test.sh` (fixture `write_orchestrator`, new case at the end, before `echo "---"`)

**Interfaces:**
- Produces: skill name `review-pro-verify`; agent name `review-pro-verify-subagent`; the reply block keys `finding`, `verdict`, `defect_stands`, `claims`, `falls`, `stands_part`, `unchecked`, `noticed`; prompt sections `### Finding`, `### Written by`, `### Diff` (first line `base: <ref>`), `### Change description`. Tasks 4 and 5 rely on these exact names.
- Produces (tests): `write_orchestrator <path> review-pro-verify` and the helper `stage_mutation`, used again by Tasks 4 and 5.

Naming note: `ORCHESTRATORS` in `validate.sh` means "pipeline-stage skills that do not follow the reviewer section contract". It is a different list from the CLI's `ORCHESTRATOR_SKILLS`, which means "stages the orchestrator runs inline". The verifier belongs in the first and must stay out of the second.

- [ ] **Step 1: Add the fixture and the helper to the meta-tests**

In `scripts/validate.test.sh`, inside `write_orchestrator`, add this branch before the `*)` branch:

```bash
    review-pro-verify)
      cat > "$1" <<'EOF'
---
name: review-pro-verify
description: "verifier"
---
# Verification
## Role
## Inputs
A file the diff deletes is read from the base with `git show <base>:<path>`.
## How to work
The change description is the author's claim; it never settles a claim.
## Verdicts
Set `defect_stands` to match.
## Rules
1. A refutation is a positive contradiction you can cite, not doubt.
2. Do not settle it from memory.
3. Judge only this finding.
## Output
EOF
      ;;
```

Then, before the final `echo "---"` line, add:

```bash
# stage_mutation <file> <writer> <expected> <label> <command...>: rewrite <file> fresh with
# <writer>, apply <command> to it, and expect <expected> as the only FAIL line.
stage_mutation(){
  local file="$1" writer="$2" want="$3" label="$4"; shift 4
  "$writer" "$file"
  "$@" "$file" > "$T/tmp"; mv "$T/tmp" "$file"
  out=$(bash "$VALIDATE" "$T" 2>&1 || true)
  local n; n=$(echo "$out" | grep -c "^FAIL: ")
  if echo "$out" | grep -qF "$want" && [[ "$n" -eq 1 ]]; then ok "$label detected, alone"; else bad "$label NOT detected in isolation ($n errors)"; fi
}

# Case AN: the verifier skill. Its sections and the five lines that keep a refutation
# honest: cite or stand, no memory, one finding only, the author's claim is not
# evidence, and deleted files are read from the base.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/review-pro-verify" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
VER="$T/core/skills/review-pro-verify/SKILL.md"
w_verify(){ write_orchestrator "$1" review-pro-verify; }
w_verify "$VER"
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"review-pro-verify","role":"verifier"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "^FAIL: "; then bad "verifier control: fired on an intact fixture"; else ok "verifier control: silent on an intact fixture"; fi
for h in "## Role" "## Inputs" "## How to work" "## Verdicts" "## Rules" "## Output"; do
  stage_mutation "$VER" w_verify "missing section '$h'" "verifier section '$h'" grep -vxF "$h"
done
stage_mutation "$VER" w_verify "the cite-or-stand rule is gone"       "verifier cite-or-stand rule"   grep -vF "positive contradiction you can cite"
stage_mutation "$VER" w_verify "the no-memory rule is gone"           "verifier no-memory rule"       grep -vF "Do not settle it from memory"
stage_mutation "$VER" w_verify "the one-finding rule is gone"         "verifier one-finding rule"     grep -vF "Judge only this finding"
stage_mutation "$VER" w_verify "no 'defect_stands' field"             "verifier defect_stands field"  grep -vF "defect_stands"
stage_mutation "$VER" w_verify "the author's-claim rule is gone"      "verifier author's-claim rule"  grep -vF "never settles a claim"
stage_mutation "$VER" w_verify "the deleted-file rule is gone"        "verifier deleted-file rule"    grep -vF 'git show <base>:'
rm -rf "$T"
```

- [ ] **Step 2: Run the meta-tests to see them fail**

Run: `bash scripts/validate.test.sh 2>&1 | tail -3`
Expected: `fail=` is greater than 0. The control fails first, because the validator does not know `review-pro-verify` and applies the reviewer section contract to it, reporting `missing section '## Role & mandate'` and eight more.

- [ ] **Step 3: Teach the validator the new stage**

In `scripts/validate.sh` line 9, replace:

```bash
ORCHESTRATORS=("review-pro" "review-pro-triage" "review-pro-synthesize")
```

with:

```bash
# Pipeline-stage skills: they do not follow the reviewer section contract, and each has
# its own required sections below. Not the CLI's ORCHESTRATOR_SKILLS, which lists the
# stages run inline; the verifier must run as a real subagent and is not in that list.
ORCHESTRATORS=("review-pro" "review-pro-triage" "review-pro-synthesize" "review-pro-verify")
```

In the per-stage `case "$name" in` block, after the `review-pro-synthesize)` line, add:

```bash
      review-pro-verify)     req=$'## Role\n## Inputs\n## How to work\n## Verdicts\n## Rules\n## Output' ;;
```

After the `if [[ -f "$SYNTH_MD" ]]; then ... fi` block that ends with the approval-standard check, add:

```bash
# The verifier's contract. Each line is what keeps a refutation from being doubt, memory,
# or the author's say-so; losing any one fails toward removing true findings.
VERIFY_MD="$SKILLS_DIR/review-pro-verify/SKILL.md"
if [[ -f "$VERIFY_MD" ]]; then
  grep -qF 'positive contradiction you can cite' "$VERIFY_MD" \
    || add_error "review-pro-verify/SKILL.md: the cite-or-stand rule is gone - a verifier could refute a true finding on doubt alone"
  grep -qF 'Do not settle it from memory' "$VERIFY_MD" \
    || add_error "review-pro-verify/SKILL.md: the no-memory rule is gone - tool and runtime behaviour would be settled from recall instead of left unchecked"
  grep -qF 'Judge only this finding' "$VERIFY_MD" \
    || add_error "review-pro-verify/SKILL.md: the one-finding rule is gone - the verifier becomes another reviewer that never runs out of things to say (ADR-0008)"
  grep -qF 'defect_stands' "$VERIFY_MD" \
    || add_error "review-pro-verify/SKILL.md: no 'defect_stands' field - synthesis cannot catch a partly_refuted that removed the defect"
  grep -qF 'never settles a claim' "$VERIFY_MD" \
    || add_error "review-pro-verify/SKILL.md: the author's-claim rule is gone - a PR description could be cited as the contradiction"
  grep -qF 'git show <base>:' "$VERIFY_MD" \
    || add_error "review-pro-verify/SKILL.md: the deleted-file rule is gone - a finding in a file the diff removes could not be re-read"
fi
```

- [ ] **Step 4: Run the meta-tests to see them pass**

Run: `bash scripts/validate.test.sh 2>&1 | tail -1`
Expected: `pass=144 fail=0` (131 + 13).

- [ ] **Step 5: Write the skill**

Create `core/skills/review-pro-verify/SKILL.md`. The Rules and Verdicts text is the spike's measured prompt (`studies/2026-09-refuting-verifier/prompt.tmpl`); change nothing in it beyond what is shown.

````markdown
---
name: review-pro-verify
description: "Stage 3b of review-pro: an independent verifier that tries to refute one merged finding from source and returns refuted, partly_refuted or stands, with the line that decides it. Use to verify a single review finding before the verdict."
version: 0.1.0
---

# Review-Pro Verification (Stage 3b)

## Role
You are an independent verifier in a code review pipeline. A specialist reviewer wrote the finding you are given. You did not write it, and you owe it nothing. Your job is to try to refute it from the source.

## Inputs
Your prompt carries:
- `### Finding`: one merged finding block, verbatim.
- `### Written by`: the reviewer that wrote it.
- `### Diff`: the diff under review. Its first line is `base: <ref>`.
- `### Change description`: the author's description of the change, when there is one.

You work in the repository's working tree, which is the branch under review. A file the diff deletes is read from the base with `git show <base>:<path>`.

## How to work
- Re-read every line the finding cites, yourself, in the working tree. Do not trust its excerpts, its line numbers, or its description of what code does.
- Split the finding into its claims: the defect it asserts, and each supporting claim the impact or the remedy depends on. Test each one.
- You may search the working tree, read its git history, and fetch upstream source code pinned to a tag or commit. Do not read issues, pull requests, discussions, or forum threads in any repository.
- Read only. Do not modify the working tree, do not build or run the project, and do not install packages.
- The change description is the author's claim; it never settles a claim, in either direction.

## Verdicts
- `refuted`: a claim the finding cannot stand without is false. You must cite the file:line (or pinned upstream source) whose content contradicts it, with the excerpt.
- `partly_refuted`: a supporting claim, or the remedy, is false, but the defect itself stands. Name what falls, what stands, and cite the contradiction for what falls.
- `stands`: you could not show any claim false.

Set `defect_stands` to `no` when the defect the finding asserts is false, and to `yes` when it stands. `refuted` goes with `no`; `partly_refuted` and `stands` go with `yes`.

## Rules
1. A refutation is a positive contradiction you can cite, not doubt. "I could not confirm it", "it seems unlikely", or "this probably is not reached in practice" is `stands`.
2. If a claim depends on runtime behaviour, a tool's behaviour, or a fact outside what you can read, and you cannot contradict it from a source you can cite, it stands, and you list it under `unchecked`. Do not settle it from memory.
3. Judge only this finding. Do not report new issues, even real ones. If you notice one, give it one line under `noticed`; it is not part of your verdict.
4. Severity is not your question. Do not refute a finding because you would rate it lower.

## Output
Reply with exactly one block, and nothing after it. Copy `finding` from the finding's `file`, `line` and `title`.

```
finding: <file>:<line> <title>
verdict: refuted | partly_refuted | stands
defect_stands: yes | no
claims:
  - claim: <one claim, in your words>
    status: false | true | unchecked
    evidence: <file:line or pinned upstream path, with a short excerpt>
falls: <what falls, or none>
stands_part: <what stands, or none>
unchecked: <what you could not check, or none>
noticed: <one line, or none>
```
````

- [ ] **Step 6: Write the agent body**

Create `core/agents/review-pro-verify-subagent.md`:

```markdown
---
name: review-pro-verify-subagent
description: Verification subagent (Stage 3b). Tries to refute one merged review finding from source and returns refuted, partly_refuted or stands with the line that decides it. Loads the review-pro-verify skill.
loads_skill: review-pro-verify
skills: [review-pro-verify]
---

# Review-Pro Verification (subagent)

You are a **review-pro subagent**. Load the `review-pro-verify` skill and follow it exactly.

## Work
1. Receive one finding with its `### Written by`, `### Diff` and, when present, `### Change description` sections.
2. Try to refute it from source, under the skill's rules. Read only: do not modify the working tree, build, run, or install anything.
3. Reply with the skill's output block and nothing else.

Judge only the finding you were given. Do NOT spawn nested subagents.
```

- [ ] **Step 7: Register both in the manifest**

In `manifest.json`, append to the `skills` array:

```json
{"name": "review-pro-verify", "role": "verifier"}
```

and to the `agents` array:

```json
{"name": "review-pro-verify-subagent", "loads_skill": "review-pro-verify"}
```

Match the file's existing spacing and indentation. `role` is only compared against `"reviewer"` (validate.sh lines 311 and 640, `cli/src/lib/catalog.ts:45`), so `verifier` keeps the reviewer count at 13.

- [ ] **Step 8: Validate the real tree**

Run: `bash scripts/validate.sh 2>&1 | tail -2; grep -c -E '—|·|→' core/skills/review-pro-verify/SKILL.md core/agents/review-pro-verify-subagent.md`
Expected: `OK: all artifacts valid`, and `0` for both files.

- [ ] **Step 9: Commit**

```bash
git add core/skills/review-pro-verify core/agents/review-pro-verify-subagent.md manifest.json scripts/validate.sh scripts/validate.test.sh
git commit -m "feat(verify): add the refuting verifier skill and subagent

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Pin the verifier's installation on every target

`cli/src` does not change. These tests pin that the verifier is installed as a real subagent everywhere, and they must go red if someone adds it to `ORCHESTRATOR_SKILLS`.

**Files:**
- Test: `cli/tests/plugin-cross.test.ts` (inside `describe("installCore per target", ...)`)
- Test: `cli/tests/uninstall.test.ts` (inside the codex uninstall `describe`)

**Interfaces:**
- Consumes: `installCore(target, pluginSrc, home, skillsHome?)` and `uninstallCore(target, pluginSrc, home, skillsHome?)` from `cli/src/lib/plugin.ts`.

- [ ] **Step 1: Write the tests**

In `cli/tests/plugin-cross.test.ts`, after the `"codex skips orchestrator subagents (triage/synthesize)"` test, add:

```ts
  const VERIFY_AGENT =
    "---\nname: review-pro-verify-subagent\ndescription: \"x\"\nloads_skill: review-pro-verify\nskills: [review-pro-verify]\n---\n# body\n";

  it("claude-code installs the verifier subagent", () => {
    fs.writeFileSync(path.join(pluginSrc, "agents", "review-pro-verify-subagent.md"), VERIFY_AGENT);
    installCore("claude-code", pluginSrc, H("cc-verify"));
    expect(fs.existsSync(path.join(H("cc-verify"), "agents", "review-pro-verify-subagent.md"))).toBe(true);
  });

  it("codex installs the verifier as a read-only subagent, unlike the inline stages", () => {
    fs.writeFileSync(path.join(pluginSrc, "agents", "review-pro-verify-subagent.md"), VERIFY_AGENT);
    installCore("codex", pluginSrc, H("codex-verify"), path.join(H("codex-verify"), "skills"));
    const toml = path.join(H("codex-verify"), "agents", "review-pro-verify-subagent.toml");
    expect(fs.existsSync(toml)).toBe(true);
    expect(fs.readFileSync(toml, "utf8")).toContain('sandbox_mode = "read-only"');
  });
```

In `cli/tests/uninstall.test.ts`, after the `"codex removes skills + reviewer .toml"` test, add:

```ts
  it("codex uninstall removes the verifier .toml", () => {
    fs.writeFileSync(
      path.join(pluginSrc, "agents", "review-pro-verify-subagent.md"),
      "---\nname: review-pro-verify-subagent\ndescription: \"x\"\nloads_skill: review-pro-verify\nskills: [review-pro-verify]\n---\n# body\n",
    );
    const home = H("codex-v");
    const sHome = path.join(home, "skills");
    installCore("codex", pluginSrc, home, sHome);
    const toml = path.join(home, "agents", "review-pro-verify-subagent.toml");
    expect(fs.existsSync(toml)).toBe(true);
    uninstallCore("codex", pluginSrc, home, sHome);
    expect(fs.existsSync(toml)).toBe(false);
  });
```

- [ ] **Step 2: Run them**

Run: `cd cli && npx vitest run tests/plugin-cross.test.ts tests/uninstall.test.ts`
Expected: PASS. The behaviour already exists; the tests pin it.

- [ ] **Step 3: Prove they bite**

In `cli/src/lib/plugin.ts:11`, temporarily change the set to `new Set(["review-pro-triage", "review-pro-synthesize", "review-pro", "review-pro-verify"])`.

Run: `cd cli && npx vitest run tests/plugin-cross.test.ts tests/uninstall.test.ts`
Expected: FAIL in `"codex installs the verifier as a read-only subagent, unlike the inline stages"` and `"codex uninstall removes the verifier .toml"`.

Revert the change: `git checkout cli/src/lib/plugin.ts`, then run `cd cli && npm test`.
Expected: all tests PASS, and `git status --short cli/src` prints nothing.

- [ ] **Step 4: Commit**

```bash
git add cli/tests/plugin-cross.test.ts cli/tests/uninstall.test.ts
git commit -m "test(cli): pin the verifier as a real subagent on every target

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Synthesis applies the results

**Files:**
- Modify: `core/skills/review-pro-synthesize/SKILL.md` (Steps, a new `## Verification` section before `## Category roots`, `## Verdict`, `## Output`)
- Modify: `core/agents/review-pro-synthesize-subagent.md` (Work step 1)
- Modify: `scripts/validate.sh` (the synthesize `req` list; the `SYNTH_MD` checks)
- Test: `scripts/validate.test.sh` (the `review-pro-synthesize` fixture; a new case)

**Interfaces:**
- Consumes: the reply block keys from Task 2 (`finding`, `verdict`, `defect_stands`, `falls`, `noticed`).
- Produces: the report strings Task 8's render check asserts: `, <N> disputed` on the verdict line, the `Verification:` line, `### Refuted in verification`, and the markers `verified`, `disputed`, `not verified (cap)`, `not verified (error)`, `not verified (no independent verifier)`.

- [ ] **Step 1: Update the fixture and add the case**

In `scripts/validate.test.sh`, in the `review-pro-synthesize)` branch of `write_orchestrator`, replace the line `## Steps` with:

```
## Steps
4. **Resolve conflicts** by ownership.
5. **Verification results** from the orchestrator.
```

and before the line `## Conflict ownership` in the same fixture, add:

```
## Verification
A refuted High or Critical keeps blocking.
Agreement does not override a refutation.
Not verified is never rendered as verified or standing.
Resolve each result by `verdict` and `defect_stands`.
### Refuted in verification
```

Before the final `echo "---"`, add:

```bash
# Case AO: synthesis's verification rules. Each one's loss fails toward shipping a
# blocker on a single refutation or toward reporting an unchecked finding as checked.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/review-pro-synthesize" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
SYN="$T/core/skills/review-pro-synthesize/SKILL.md"
w_synth(){ write_orchestrator "$1" review-pro-synthesize; }
w_synth "$SYN"
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"review-pro-synthesize","role":"orchestrator"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "^FAIL: "; then bad "synthesis verification control: fired on an intact fixture"; else ok "synthesis verification control: silent on an intact fixture"; fi
stage_mutation "$SYN" w_synth "missing section '## Verification'"             "synthesis Verification section"      grep -vxF "## Verification"
stage_mutation "$SYN" w_synth "the disputed-blocker rule is gone"              "synthesis disputed-blocker rule"     grep -vF "keeps blocking"
stage_mutation "$SYN" w_synth "the agreement rule is gone"                     "synthesis agreement rule"            grep -vF "Agreement does not override a refutation"
stage_mutation "$SYN" w_synth "the not-verified rule is gone"                  "synthesis not-verified rule"         grep -vF "never rendered as verified or standing"
stage_mutation "$SYN" w_synth "no 'defect_stands' resolution"                  "synthesis defect_stands resolution"  grep -vF "defect_stands"
stage_mutation "$SYN" w_synth "the refuted section is gone"                    "synthesis refuted section"           grep -vF "Refuted in verification"
stage_mutation "$SYN" w_synth "verification runs before conflict resolution"   "synthesis step order"                sed -e 's/\*\*Resolve conflicts\*\*/@@T@@/' -e 's/\*\*Verification results\*\*/**Resolve conflicts**/' -e 's/@@T@@/**Verification results**/'
rm -rf "$T"
```

- [ ] **Step 2: Run the meta-tests to see them fail**

Run: `bash scripts/validate.test.sh 2>&1 | tail -3`
Expected: `fail=` greater than 0: the six mutations after the control are not detected, because the validator has none of these checks.

- [ ] **Step 3: Add the checks**

In `scripts/validate.sh`, in the per-stage `case`, replace the synthesize line with:

```bash
      review-pro-synthesize) req=$'## Steps\n## Out-of-diff evidence check\n## Spec axis\n## Verification\n## Conflict ownership\n## Output' ;;
```

After the existing `if [[ -f "$SYNTH_MD" ]]; then ... fi` block that ends with the approval-standard check (and before the `VERIFY_MD` block from Task 2), add:

```bash
# Verification. The asymmetry is the whole safety argument of ADR-0009: one wrong
# refutation must not ship a blocker, and an unchecked finding must not read as checked.
if [[ -f "$SYNTH_MD" ]]; then
  grep -qF 'keeps blocking' "$SYNTH_MD" \
    || add_error "review-pro-synthesize/SKILL.md: the disputed-blocker rule is gone - one wrong refutation would remove a High or Critical from the verdict"
  grep -qF 'Agreement does not override a refutation' "$SYNTH_MD" \
    || add_error "review-pro-synthesize/SKILL.md: the agreement rule is gone - 'flagged by N reviewers' would outweigh a cited contradiction"
  grep -qF 'never rendered as verified or standing' "$SYNTH_MD" \
    || add_error "review-pro-synthesize/SKILL.md: the not-verified rule is gone - a capped or failed check could read as a clean one"
  grep -qF 'defect_stands' "$SYNTH_MD" \
    || add_error "review-pro-synthesize/SKILL.md: no 'defect_stands' resolution - a partly_refuted that removed the defect would stay in the verdict"
  grep -qF 'Refuted in verification' "$SYNTH_MD" \
    || add_error "review-pro-synthesize/SKILL.md: the refuted section is gone - a refuted Medium would leave the report instead of staying visible"
  rc=$(grep -nF '**Resolve conflicts**' "$SYNTH_MD" | head -1 | cut -d: -f1)
  vr=$(grep -nF '**Verification results**' "$SYNTH_MD" | head -1 | cut -d: -f1)
  if [[ -z "$vr" ]]; then
    add_error "review-pro-synthesize/SKILL.md: the verification step is gone from Steps"
  elif [[ -n "$rc" && "$rc" -gt "$vr" ]]; then
    add_error "review-pro-synthesize/SKILL.md: verification runs before conflict resolution - a finding the owner raises to Medium afterwards is never selected"
  fi
fi
```

- [ ] **Step 4: Run the meta-tests to see them pass**

Run: `bash scripts/validate.test.sh 2>&1 | tail -1`
Expected: `pass=152 fail=0` (144 + 8).

- [ ] **Step 5: Rewrite synthesis's Steps**

In `core/skills/review-pro-synthesize/SKILL.md`, replace the whole numbered list under `## Steps` (lines 12 to 18) with:

```markdown
1. **Collect** all finding blocks from the dispatched reviewers.
2. **Dedup** by `(file, line±5, category-root, overlap_hints)`: the same issue flagged by multiple reviewers collapses into one.
3. **Weight:** annotate a finding flagged by 2 or more reviewers "flagged by N reviewers". It is a note about coverage, not evidence: see `## Verification`.
4. **Resolve conflicts** by ownership: the domain owner sets severity (see table).
5. **Verification results**: the orchestrator verifies the merged Medium+ code findings at this point and hands you the results. Apply them as `## Verification` says before going on.
6. **Calibrate severity:** enforce the anti-overreporting bar. Downgrade anything not fully traced to evidence. Never upgrade beyond what a specialist justified.
7. **Out-of-diff evidence check** (see below): a review-level confidence signal, not a per-finding gate.
8. **Verdict** + prioritized findings + remediations.

When you run inline, steps 1 to 4 are what the orchestrator runs before it dispatches the verifiers.
```

- [ ] **Step 6: Add the Verification section**

Insert before `## Category roots`:

````markdown
## Verification

The orchestrator selects the code-axis findings at Medium or above, after step 4, in severity order and then by file and line, and sends the first 8 to independent verifiers. Spec-axis findings are not verified. You receive one reply block per verified finding.

**Binding.** A block binds to the finding whose `file`, `line` and `title` match its `finding` key. A reply with no block, with more than one block, or with a key that matches no finding or more than one leaves that finding `not verified (error)`.

**Resolve each result** by `verdict` and `defect_stands`. Every inconsistency resolves in the cautious direction:

| `verdict` | `defect_stands` | treated as |
|---|---|---|
| `refuted` | `no` | refuted |
| `partly_refuted` | `yes` | partly refuted |
| `partly_refuted` | `no` | refuted |
| `stands` | `yes` | stands |
| `refuted` | `yes` | not verified (error) |
| `stands` | `no` | not verified (error) |

**Apply it:**

| treated as | Medium | High / Critical |
|---|---|---|
| stands | unchanged, marked `verified` | unchanged, marked `verified` |
| partly refuted | severity unchanged; show what falls and its citation under the finding | same |
| refuted | leaves the verdict; moves to `### Refuted in verification` | keeps blocking; marked `disputed`, with the citation |
| not verified | unchanged, marked `not verified (<reason>)` | same |

- A refuted High or Critical keeps blocking. One refutation is not enough to ship a blocker; a human clears a `disputed` finding.
- Agreement does not override a refutation. "Flagged by N reviewers" stays as a note and protects nothing.
- Not verified is never rendered as verified or standing. The reason is `cap` for a finding past the first 8, `error` for anything under Binding or the inconsistent rows above, and `no independent verifier` when no verifier ran.
- If you run as a subagent and receive no verification results, every code-axis finding at Medium or above is `not verified (no independent verifier)`.
- `partly refuted` never changes severity. Severity is not the verifier's question.
- A `noticed` line goes under its own finding, at most one per finding, labelled `not reviewed`. It is never a finding and never enters the verdict.
````

- [ ] **Step 7: Update the verdict rules**

Replace:

```markdown
- **BLOCK:** any unaddressed Critical or High.
- **REQUEST CHANGES:** any Medium or above.
- **APPROVE:** only Low/Nitpick, or no findings.
```

with:

```markdown
- **BLOCK:** any unaddressed Critical or High, `disputed` ones included.
- **REQUEST CHANGES:** any Medium or above that verification did not refute.
- **APPROVE:** only Low/Nitpick, refuted Mediums, or no findings.
```

- [ ] **Step 8: Update the output template**

In the `## Output` code block, replace the first line:

```
## Verdict: <BLOCK | REQUEST CHANGES> (<code | spec | code + spec>) | APPROVE
```

with:

```
## Verdict: <BLOCK | REQUEST CHANGES> (<code | spec | code + spec>)[, <N> disputed] | APPROVE
```

After the line `(or: skipped, no spec found / not measured, <ref> resolved but carried no text)`, add:

```

Verification: <N> checked (<a> stand, <b> partly refuted, <c> refuted), <M> not checked (<counts by reason>). Spec findings are not verified.
```

After the line `  flagged by: security, backend` in the Critical example, add:

```
  verification: verified
```

After the `### Medium / Low / Nitpick` line and its `...`, add:

```

### Refuted in verification
- [Medium] src/cart/total.ts:30, discount is applied twice
  refuted: "applyDiscount runs again in checkout()"
  contradicted by: src/cart/checkout.ts:12 `const total = cart.total // already discounted`
  noticed (not reviewed): the discount rounding is untested
```

- [ ] **Step 9: Update the synthesis subagent body**

In `core/agents/review-pro-synthesize-subagent.md`, replace Work step 1 with:

```markdown
1. Receive the structured findings from all dispatched reviewers, plus `diff_class`, `changed_files`, and `spec_source` from triage's dispatch plan (the first two for the out-of-diff evidence check, which counts code-axis findings only; `spec_source` for the Spec section's header and skip note), and the verification results when the orchestrator ran the verifiers. If any is absent, skip the part that needs it and say so. With no verification results, every code-axis finding at Medium or above is `not verified (no independent verifier)`.
```

- [ ] **Step 10: Validate and commit**

Run: `bash scripts/validate.sh 2>&1 | tail -1; bash scripts/validate.test.sh 2>&1 | tail -1; git diff -U0 | grep '^+' | grep -c -E '—|·|→'`
Expected: `OK: all artifacts valid`, `pass=152 fail=0`, `0`.

```bash
git add core/skills/review-pro-synthesize/SKILL.md core/agents/review-pro-synthesize-subagent.md scripts/validate.sh scripts/validate.test.sh
git commit -m "feat(synthesize): apply verification results asymmetrically

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: The orchestrator dispatches the verifiers

**Files:**
- Modify: `core/skills/review-pro/SKILL.md` (new `### 4. Verification`; `### 4. Synthesis` becomes `### 5.`; `## Output`; `## Rules`)
- Modify: `scripts/validate.sh` (the `ORCH_MD` checks)
- Test: `scripts/validate.test.sh` (a `review-pro` fixture branch; a new case)

**Interfaces:**
- Consumes: agent name `review-pro-verify-subagent` and prompt sections from Task 2; synthesis step numbers 1 to 4 from Task 4.

- [ ] **Step 1: Add the fixture and the case**

In `write_orchestrator`, add before the `*)` branch:

```bash
    review-pro)
      cat > "$1" <<'EOF'
---
name: review-pro
description: "orchestrator"
---
# Review-Pro
Dedup the spec pool on the quoted requirement.
### External premises
Invoke one `review-pro-verify-subagent` per selected finding.
`### Diff`: first line `base: <ref>`.
`### Written by`: the reviewer that wrote it. Never how many reviewers flagged it.
If the verify subagent is unavailable, do **not** verify inline.
EOF
      ;;
```

Before the final `echo "---"`, add:

```bash
# Case AP: the orchestrator's verification step. Without the dispatch the stage never
# runs; without the ban the orchestrator checks its own findings, which is not independent.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/review-pro" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
ORC="$T/core/skills/review-pro/SKILL.md"
w_orch(){ write_orchestrator "$1" review-pro; }
w_orch "$ORC"
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"review-pro","role":"orchestrator"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "^FAIL: "; then bad "orchestrator verification control: fired on an intact fixture"; else ok "orchestrator verification control: silent on an intact fixture"; fi
stage_mutation "$ORC" w_orch "the verifier dispatch is gone"       "orchestrator verifier dispatch"  grep -vF "review-pro-verify-subagent"
stage_mutation "$ORC" w_orch "the inline-verification ban is gone" "orchestrator inline ban"         grep -vF 'do **not** verify inline'
stage_mutation "$ORC" w_orch "the agreement-count ban is gone"     "orchestrator agreement-count ban" grep -vF "Never how many reviewers flagged it"
stage_mutation "$ORC" w_orch "the base line is gone"               "orchestrator base line"          grep -vF 'base: <ref>'
rm -rf "$T"
```

- [ ] **Step 2: Run the meta-tests to see them fail**

Run: `bash scripts/validate.test.sh 2>&1 | tail -3`
Expected: `fail=4`: none of the four mutations is detected.

- [ ] **Step 3: Add the checks**

In `scripts/validate.sh`, inside the existing `if [[ -f "$ORCH_MD" ]]; then ... fi` block, after the `### External premises` check, add:

```bash
  grep -qF 'review-pro-verify-subagent' "$ORCH_MD" \
    || add_error "review-pro/SKILL.md: the verifier dispatch is gone - Stage 3b never runs and every finding reads as unverified"
  grep -qF 'do **not** verify inline' "$ORCH_MD" \
    || add_error "review-pro/SKILL.md: the inline-verification ban is gone - the orchestrator would check its own findings, which is not independent"
  grep -qF 'Never how many reviewers flagged it' "$ORCH_MD" \
    || add_error "review-pro/SKILL.md: the agreement-count ban is gone - verifiers would be told how many reviewers agreed, which is pressure, not evidence"
  grep -qF 'base: <ref>' "$ORCH_MD" \
    || add_error "review-pro/SKILL.md: the base line is gone - a verifier cannot re-read a file the diff deletes"
```

- [ ] **Step 4: Run the meta-tests to see them pass**

Run: `bash scripts/validate.test.sh 2>&1 | tail -1`
Expected: `pass=157 fail=0` (152 + 5).

- [ ] **Step 5: Add the verification step**

In `core/skills/review-pro/SKILL.md`, insert before `### 4. Synthesis (you, inline)`:

```markdown
### 4. Verification (subagents, parallel)
Verification needs the merged findings, so first run steps 1 to 4 of the `review-pro-synthesize` skill (collect, dedup, weight, resolve conflicts). Then:

1. **Select** the code-axis findings with severity Medium, High or Critical, ordered by severity and then by file and line. Take the first 8; the rest are `not verified (cap)`. Spec-axis findings are never verified.
2. **Invoke one `review-pro-verify-subagent` per selected finding**, in parallel if your platform allows, else sequentially. Its prompt contains:
   - `### Finding`: the merged finding block, verbatim.
   - `### Written by`: the reviewer that wrote it. Never how many reviewers flagged it; that count is pressure, not evidence.
   - `### Diff`: first line `base: <ref>`, then the output of `git diff <base>...HEAD`.
   - `### Change description`: the PR body or the invocation's description, when there is one. Omit the section otherwise.
3. **Collect** each reply. A reply that errors, times out, or carries no parseable block leaves its finding `not verified (error)`.

If the verify subagent is unavailable on your platform, do **not** verify inline: a check in your own context is not independent. Mark every selected finding `not verified (no independent verifier)` and continue.
```

Rename the next heading from `### 4. Synthesis (you, inline)` to `### 5. Synthesis (you, inline)`, and in its paragraph replace `Follow the \`review-pro-synthesize\` skill over ALL collected findings, passing it` with `Continue the \`review-pro-synthesize\` skill from step 5, with the verification results, passing it`.

- [ ] **Step 6: Update the orchestrator's output template and rules**

In the `## Output` code block, replace the first line exactly as in Task 4 Step 8, and add the same `Verification:` line after the `(or: skipped, ...)` line. After the `### Medium / Low / Nitpick` line and its `...`, add:

```

### Refuted in verification
- [Medium] <file>:<line>, <title>
  refuted: "<the claim>"
  contradicted by: <file>:<line> `<excerpt>`
```

In `## Rules`, add a last bullet:

```markdown
- **Never verify a finding in your own context.** Verification is independent or it does not happen, and the report says which.
```

- [ ] **Step 7: Validate and commit**

Run: `bash scripts/validate.sh 2>&1 | tail -1; bash scripts/validate.test.sh 2>&1 | tail -1; git diff -U0 | grep '^+' | grep -c -E '—|·|→'`
Expected: `OK: all artifacts valid`, `pass=157 fail=0`, `0`.

```bash
git add core/skills/review-pro/SKILL.md scripts/validate.sh scripts/validate.test.sh
git commit -m "feat(orchestrator): dispatch one verifier per Medium+ code finding

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Contract run (acceptance 1, pre-registered)

Measures whether the two unmeasured changes (`defect_stands`, working-tree wording) shifted what the spike measured.

**Files:**
- Create: `studies/2026-09-refuting-verifier/acceptance/PRE-REGISTRATION.md`
- Create: `studies/2026-09-refuting-verifier/acceptance/RESULTS.md`
- Create: `studies/2026-09-refuting-verifier/acceptance/raw/<item>.md` (13 files)

- [ ] **Step 1: Check the checkouts exist**

Run: `ls /private/tmp/claude-501/-Users-tufantunc-Desktop-Projects-Personal-review-pro/95411138-7910-4558-b74e-6fcf6b3a3445/scratchpad/verifier-spike/repos/`
Expected: `aspire extensions nbgv probe-p2-envflag probe-p5-control rp51 rp71` and their `.diff.patch` files. If the scratchpad is gone, rebuild them from the table in `studies/2026-09-refuting-verifier/README.md`: `git init`, `git fetch --filter=blob:none origin <head> <base>`, `git checkout <head>`, `git diff <base> <head> > <name>.diff.patch`; for rp51, check out the base, `git checkout <#51 head> -- .`, remove the rationale paragraph and set the message to `npm install --package-lock-only`, commit, and prune the original head.

- [ ] **Step 2: Write the pre-registration before any run**

Create `studies/2026-09-refuting-verifier/acceptance/PRE-REGISTRATION.md`:

```markdown
# Contract run: pre-registration (written before any run)

Question: does the shipped `review-pro-verify` skill, with `defect_stands` and the
working-tree wording, behave as the spike's prompt did on the same 13 findings?

Labels, corrected after the spike (see ../RESULTS.md):
- FALSE: V01, V06, V08, V11 (V11's defect falls; only a doc-comment inaccuracy stands).
- MIXED: V04 (the RoutingHandler claim falls, the coverage gap stands).
- TRUE: V02, V03, V05, V07, V09, V12, V13.
- OUT-OF-REPO, not scored: V10.

One run per item, general-purpose agent, prompt built from the skill's Inputs section.

Pass, all three:
1. No TRUE item and not V04's core treated as refuted (per the synthesis resolution table).
2. At least 3 of the 4 FALSE items treated as refuted.
3. `defect_stands` consistent with `verdict` in at least 12 of 13 replies.

Predictions: V06, V08, V11 refuted; V01 partly_refuted with defect_stands yes (a miss,
as in the spike); V04 partly_refuted with defect_stands yes; every TRUE item stands or
partly_refuted with defect_stands yes; 13 of 13 consistent.
```

Commit it before Step 3: `git add studies/2026-09-refuting-verifier/acceptance/PRE-REGISTRATION.md && git commit -m "docs(studies): pre-register the verifier contract run" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"`.

- [ ] **Step 3: Build the 13 prompts**

Run:

````bash
python3 - <<'EOF'
import os, re, subprocess
V = "/private/tmp/claude-501/-Users-tufantunc-Desktop-Projects-Personal-review-pro/95411138-7910-4558-b74e-6fcf6b3a3445/scratchpad/verifier-spike"
S = "/Users/tufantunc/Desktop/Projects/Personal/review-pro"
git = lambda *a: subprocess.run(["git", *a], capture_output=True, text=True, check=True).stdout.strip()
BASE = {
    "aspire": "5552e243d46b14394ec1b024576f3d9faaf87ec2",
    "nbgv": "a147f03ed4ef80033d552c5ea82b69c3233c4966",
    "extensions": "7e8c785af5db6300f0ec5c0ae5f50811237c658e",
    "rp51": "12e002383a69bf45baf1ba929a4c44aa13f7eb5c",
    "rp71": git("-C", S, "merge-base", "3567891a", "72712f6~1"),
}
out = f"{V}/acceptance-prompts"; os.makedirs(out, exist_ok=True)
for n in range(1, 14):
    k = f"V{n:02d}"; t = open(f"{S}/studies/2026-09-refuting-verifier/items/{k}.md").read()
    repo = re.search(r"^Checkout .*?: (.+)$", t, re.M).group(1)
    name = os.path.basename(repo)
    base = BASE.get(name) or git("-C", repo, "rev-parse", "HEAD~1")  # probes: one commit on the base
    change = re.search(r"^Change: (.+)$", t, re.M).group(1)
    who = re.search(r"^Written by: the `(.+?)` reviewer$", t, re.M).group(1)
    block = re.search(r"```\n(.*?)```", t, re.S).group(1)
    diff = open(repo + ".diff.patch").read()
    p = (f"Read {S}/core/skills/review-pro-verify/SKILL.md and follow it exactly, as the "
         f"review-pro-verify-subagent would. Your working tree is {repo}; run every command there.\n\n"
         f"### Finding\n{block}\n### Written by\n{who}\n\n### Diff\nbase: {base}\n{diff}\n"
         f"### Change description\n{change}\n")
    open(f"{out}/{k}.md", "w").write(p)
print(sorted(os.listdir(out)))
EOF
````

Expected: `['V01.md', ..., 'V13.md']`.

- [ ] **Step 4: Dispatch the 13 runs**

In one message, dispatch 13 `general-purpose` agents in the background, each with the full text of one prompt file as its prompt, and description `Verify contract <item>`.

- [ ] **Step 5: Record**

Save each reply verbatim to `studies/2026-09-refuting-verifier/acceptance/raw/<item>.md`. Write `RESULTS.md` with one row per item: `verdict`, `defect_stands`, treated-as (per the synthesis resolution table), consistent (y/n), and scored outcome; then the three pass conditions with their counts, and the predictions that failed. If any condition fails, stop and report to the user before Task 7: that is a result, not a bug to tune away (see the 2026-09-23 wording spike, where every rewrite moved severity).

- [ ] **Step 6: Commit**

```bash
git add studies/2026-09-refuting-verifier/acceptance
git commit -m "docs(studies): record the verifier contract run

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: ADR-0009 and the docs

**Files:**
- Create: `docs/internals/adr/0009-verify-findings-by-refutation.md`
- Modify: `README.md` (both pipeline bullet lists; the mermaid Stage 3 subgraph)
- Modify: `docs/internals/glossary.md`

- [ ] **Step 1: Write the ADR**

Create `docs/internals/adr/0009-verify-findings-by-refutation.md`:

```markdown
# 0009: Verify each blocking-level finding by trying to refute it

Status: accepted
Date: 2026-09-24

## Context

Synthesis merged findings but never re-checked one, and it treated agreement as
strength. The #51 libc claim and the pilot's case-3 `dotnet run` finding were both
several readers agreeing on something none of them traced to its source; the second was
filed upstream as microsoft/aspire#19540 before anyone noticed. A pre-registered spike
([studies/2026-09-refuting-verifier](../../../studies/2026-09-refuting-verifier)) gave
13 labelled findings to fresh agents told to refute each one from source: 6 of 8 runs on
known-false findings refuted them, none added new findings, and the only true-labelled
finding they refuted turned out to be labelled wrong.

## Decision

One fresh agent per Medium+ code finding, after dedup and conflict resolution and before
the verdict, tries to refute it and must cite the line that contradicts it. A refuted
Medium leaves the verdict and stays visible; a refuted High or Critical keeps blocking
and is marked disputed.

Rejected: verifying each reviewer's findings as they arrive, which verifies duplicates and
makes a cap meaningless.

Rejected: one verifier for all findings in one context, which was never measured and lets
one judgement bleed into the next.

Rejected: letting a refutation remove a High or Critical. The evidence is 13 findings, one
model family in every role, and labels that were wrong in 2 of 13; a wrong refutation
there ships a blocker.

## Consequences

A false Medium no longer costs the author a REQUEST CHANGES, and a false blocker is flagged
for a human instead of silently holding a merge. Up to 8 extra agents per review, about 70k
tokens each. Spec findings are not verified. Where no independent subagent exists, nothing
is verified and the report says so. A wrong refutation can still take a real Medium out of
the verdict; the asymmetry bounds that to non-blocking findings and does not remove it.
Revisiting the High/Critical rule needs a larger corpus, with labels checked by someone
other than the maintainer, showing refutations of blockers are reliably right.
```

- [ ] **Step 2: Update the README**

In `README.md`, after the bullet that starts `- **Synthesis** dedups overlaps, resolves cross-reviewer conflicts` (in `## Why`), add:

```markdown
- **Verification** sends each Medium or higher finding, after dedup, to a fresh agent told to refute it from source. A refutation must cite the line that contradicts the finding. A refuted Medium leaves the verdict but stays in the report; a refuted High or Critical keeps blocking and is marked disputed ([ADR-0009](docs/internals/adr/0009-verify-findings-by-refutation.md)).
```

After the bullet that starts `- **Synthesis** dedups, weights, resolves conflicts by domain ownership` (under the diagram), add:

```markdown
- **Verification** runs one independent refuter per Medium+ code finding, at most 8 per review, between dedup and the verdict.
```

In the mermaid block, replace:

```
    T --> R1 & R2 & R3 & R4
    R1 & R2 & R3 & R4 --> Y
```

with:

```
    X["independent verifier<br/>one per Medium+ finding"]
    T --> R1 & R2 & R3 & R4
    R1 & R2 & R3 & R4 --> Y
    Y <--> X
```

- [ ] **Step 3: Update the glossary**

In `docs/internals/glossary.md`, after the `synthesis` line, add:

```markdown
- **verification** (Stage 3b): one fresh agent per Medium+ code finding tries to refute it from source; a refutation must cite a contradicting line. See ADR-0009.
- **disputed**: a High or Critical finding a verifier refuted. It keeps blocking until a human clears it.
```

- [ ] **Step 4: Validate and commit**

Run: `bash scripts/validate.sh 2>&1 | tail -1; git diff -U0 | grep '^+' | grep -c -E '—|·|→'`
Expected: `OK: all artifacts valid`, `0`. (The README count guard is unaffected: the reviewer count stays 13.)

```bash
git add docs/internals/adr/0009-verify-findings-by-refutation.md README.md docs/internals/glossary.md
git commit -m "docs: ADR-0009 and the verification stage in the README

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Render check (acceptance 3, pre-registered)

Exercises the synthesis branches a real review rarely reaches: the cap, every not-verified reason, the disputed counter, the refuted section, and the subagent path with no results.

**Files:**
- Create: `studies/2026-09-refuting-verifier/acceptance/render/INPUT.md`
- Create: `studies/2026-09-refuting-verifier/acceptance/render/EXPECTED.md`
- Create: `studies/2026-09-refuting-verifier/acceptance/render/OUTPUT-inline.md`, `OUTPUT-no-results.md`

- [ ] **Step 1: Write the input**

Create `INPUT.md` with 11 merged code findings in the shared schema (`file`, `line`, `title`, `severity`, `category`, `evidence`, `impact`, `remedy`), `diff_class: substantive`, `changed_files: [src/a.ts, src/b.ts, src/c.ts]`, `spec_source: {kind: none}`, and these findings (all in `src/a.ts` unless noted, lines as given):

| id | line | severity | title |
|---|---|---|---|
| F1 | 10 | Critical | unauthenticated role change |
| F2 | 20 | High | token logged at info level |
| F3 | 30 | Medium | discount applied twice |
| F4 | 40 | Medium | retry loop has no backoff |
| F5 | 50 | Medium | cache key omits tenant |
| F6 | 60 | Medium | error swallowed in parser |
| F7 | 70 | Medium | pagination skips last page |
| F8 | 80 | Medium | stale lock never released |
| F9 | `src/b.ts` 5 | Medium | timezone dropped on save |
| F10 | `src/c.ts` 5 | Medium | N+1 query in list view |
| F11 | `src/c.ts` 9 | Low | variable name misleading |

and these verification replies (F9 and F10 have none, being past the cap):

| reply | `finding` key | `verdict` | `defect_stands` | shape |
|---|---|---|---|---|
| R1 | `src/a.ts:10 unauthenticated role change` | refuted | no | one block |
| R2 | `src/a.ts:20 token logged at info level` | stands | yes | one block |
| R3 | `src/a.ts:30 discount applied twice` | refuted | no | one block, with `noticed: rounding untested` |
| R4 | `src/a.ts:40 retry loop has no backoff` | partly_refuted | yes | one block, `falls: the remedy's jitter claim` |
| R5 | `src/a.ts:50 cache key omits tenant` | partly_refuted | no | one block |
| R6 | `src/a.ts:60 error swallowed in parser` | stands | no | one block |
| R7 | `src/a.ts:70 pagination skips last page` | stands | yes | two blocks |
| R8 | `src/a.ts:81 stale lock never released` | stands | yes | one block (line does not match) |

Give each reply a plausible `claims` list and a contradicting `file:line` excerpt where it refutes.

- [ ] **Step 2: Write the expectation before running**

Create `EXPECTED.md`:

```markdown
Inline run (results given):
- Verdict line: `## Verdict: BLOCK (code), 1 disputed`
- Verification line: `Verification: 5 checked (1 stand, 1 partly refuted, 3 refuted), 5 not checked (3 error, 2 cap). Spec findings are not verified.`
  (checked: F1, F3, F5 refuted, F5 through the partly_refuted/no row; F4 partly refuted; F2 stands.
  not checked: F6 inconsistent, F7 two blocks, F8 unbound, all `error`; F9, F10 `cap`.)
- F1 stays under Critical, marked disputed, with its citation.
- F2 under High, marked verified.
- F3 and F5 under `### Refuted in verification`; F3 carries `noticed (not reviewed): rounding untested`.
- F4 under Medium at Medium, with the falling part and its citation beneath it.
- F6, F7, F8 under Medium, each `not verified (error)`; F9, F10 `not verified (cap)`.
- F11 under Low, with no verification marker.

No-results run (same findings, no replies, as a subagent):
- `## Verdict: BLOCK (code)` with no disputed counter.
- `Verification: 0 checked, 10 not checked (10 no independent verifier). Spec findings are not verified.`
- F1 to F10 each `not verified (no independent verifier)`; no `### Refuted in verification` section.
```

Commit `INPUT.md` and `EXPECTED.md` before Step 3.

- [ ] **Step 3: Run both**

Dispatch two `general-purpose` agents in parallel. Prompt 1: "Read `<repo>/core/skills/review-pro-synthesize/SKILL.md` and follow it from step 1, running inline. The verification results are the replies in `<repo>/studies/2026-09-refuting-verifier/acceptance/render/INPUT.md`. Return only the report." Prompt 2: the same, but "you are running as the review-pro-synthesize-subagent and received no verification results; ignore the replies section."

Save the reports as `OUTPUT-inline.md` and `OUTPUT-no-results.md`.

- [ ] **Step 4: Compare and commit**

Check every bullet of `EXPECTED.md` against the outputs and record pass or fail per bullet at the end of `EXPECTED.md` under `## Result`. A failed bullet is fixed in the synthesis text (Task 4's files), the meta-tests re-run, and both render runs repeated; record each repeat.

```bash
git add studies/2026-09-refuting-verifier/acceptance/render
git commit -m "docs(studies): render check for verification in synthesis

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: End-to-end run (acceptance 2, pre-registered)

**Files:**
- Create: `studies/2026-09-refuting-verifier/acceptance/e2e/PRE-REGISTRATION.md`, `aspire-report.md`, `control-report.md`, `RESULTS.md`

- [ ] **Step 1: Pre-register**

Create `e2e/PRE-REGISTRATION.md`:

```markdown
# End-to-end run: pre-registration (written before any run)

Pipeline: this branch's `core/skills/review-pro/SKILL.md`, followed by the session
agent as orchestrator; reviewers and verifiers are general-purpose agents told to
read this branch's rubric and verify skill files (the installed copies predate them).

Diffs:
- A: microsoft/aspire#18671, base 5552e243, head 8eeb25bd (pilot case 3).
- B (control): the step-2 probe `p4-control` branch, where the only expected finding is a
  Low citing kong.yml.

Pass:
- A: if any finding claims the `dotnet run` sites leave the flake unmitigated or the
  timeout invariant inverted, it comes out refuted (if Medium) or disputed (if High).
  If no reviewer produces it, record that; it is not a failure.
- A: the report carries the Verification line, and every Medium+ code finding carries a
  verification marker.
- A and B: no finding is verified in the orchestrator's own context.
- B: `Verification: 0 checked` and an otherwise intact report.
```

Commit it before Step 2.

- [ ] **Step 2: Run A**

In the aspire checkout from Task 6 Step 1, follow `core/skills/review-pro/SKILL.md` from this branch with the argument `5552e243d46b14394ec1b024576f3d9faaf87ec2` as the base. Dispatch reviewers as general-purpose agents told to read `<repo>/core/skills/<reviewer>/SKILL.md` and follow it, and verifiers as general-purpose agents told to read `<repo>/core/skills/review-pro-verify/SKILL.md` and follow it with the step-4 prompt sections. Save the final report as `aspire-report.md`.

- [ ] **Step 3: Run B**

The same, on `/private/tmp/claude-501/-Users-tufantunc-Desktop-Projects-Personal-review-pro/95411138-7910-4558-b74e-6fcf6b3a3445/scratchpad/nv-spike/repo` with `git checkout p4-control` and base `p4-control~1`. Save as `control-report.md`.

- [ ] **Step 4: Record and commit**

Write `e2e/RESULTS.md`: each pass condition, met or not, with the lines of the report that show it, plus token and time totals for the verifiers.

```bash
git add studies/2026-09-refuting-verifier/acceptance/e2e
git commit -m "docs(studies): end-to-end run of the verification stage

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Pull request and review

- [ ] **Step 1: Final checks**

Run: `bash scripts/validate.sh 2>&1 | tail -1; bash scripts/validate.test.sh 2>&1 | tail -1; (cd cli && npm test 2>&1 | tail -3)`
Expected: `OK: all artifacts valid`, `pass=157 fail=0`, vitest all passing.

- [ ] **Step 2: Push and open the PR**

```bash
git push -u origin feat/refuting-verifier
gh pr create --title "feat: verify each Medium+ finding by trying to refute it (ADR-0009)" --body-file <body>
```

The body states what the stage does, the asymmetry and why, the three acceptance results with links, the spec amendments from Task 1, and the open risks from the spec's Limitations. End it with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

- [ ] **Step 3: Review with review-pro, verifier on**

Run the branch's pipeline on the PR diff as in Task 9, with the verification stage active. Fix what it finds that holds, re-run the checks in Step 1, and push. Merge only when the review raises nothing unaddressed; delete the branch. Do not cut a release.
