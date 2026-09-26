# Coverage spike: pre-registration (written before any run)

Diff: #74, c33da43..8649dad, 119 files (17 code/skill/doc files outside studies/, 102 study data files).
Reviewers: correctness-reviewer, craft-reviewer, tests-reviewer. One run each. Real agent bodies, unmodified,
plus a temporary addendum asking for a `## Files examined` block.

## Questions and how each is measured

Q1 compliance: does each reviewer emit the block at all?
Q2 declared skips: per reviewer, count of not_examined files, split into studies/ vs the 17 others, with reasons.
Q3 omissions: files in neither list (silently absent from the declaration itself).
Q4 overclaims: files declared examined for which the subagent transcript shows no tool call that put that
    file's content or hunk in view (Read of it, a git diff/show naming it, or a whole-commit diff whose
    output was not truncated). Measured from the subagent jsonl transcripts.
Q5 contradictions: a finding whose `file` is declared not_examined.

## Decision rules fixed now

- D1: any non-studies file declared not_examined by all three reviewers => the per-file signal matters;
  render not-examined non-docs files by name.
- D2: skips confined to study/data files with a stated reason => the line must group skips and must not
  warn for them (docs/data exemption justified by data, not taste).
- D3: overclaims >= 1 file in any reviewer => "self-reported" label is mandatory and the report must
  never render the declaration as coverage; a declared-examined count is not a checkmark.
- D4: Q1 fails for any reviewer (no block) => the "not reported" path is not hypothetical and needs a
  validator-guarded rendering.
- Stop rule: if a single run exceeds ~250k tokens, do not run more; report and ask.
