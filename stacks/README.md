# Stack packs

A stack pack **supplements** a core reviewer rubric with language/framework-specific signals, remedies, severity notes, and examples. The core rubric defines the *lens*; the pack makes it concrete for a stack.

## Composition (runtime)

A reviewer's **effective rubric** is composed by the orchestrator at dispatch time:

```
effective_rubric(<reviewer>) = core/skills/<reviewer>/SKILL.md
                             + Σ stacks/<active_stack>/<reviewer>.md
```

Use `scripts/compose-rubric.sh` to render the effective rubric for a reviewer and a set of active stacks:

```bash
scripts/compose-rubric.sh security typescript-react   # core security + ts-react security pack
```

Active stacks are determined per repo by triage (detected from manifests, merged with `review-pro.config.stack_packs`). A pack only contributes for reviewers where it has a file; reviewers without a pack file run on their core rubric alone.

## File format

Each pack file is plain markdown:

```markdown
# Stack pack: <stack> — <reviewer>
extends: core/skills/<reviewer>/SKILL.md

## Stack-specific signals
- concrete thing to flag in this stack

## Stack-specific remedies
- concrete fix in this stack

## Stack-specific severity guidance
- how this stack adjusts severity

## Example
...
```

## Per-stack manifest

Each pack directory has a `manifest.json` listing the reviewers it supplements (the validator checks every listed file exists and targets a real reviewer):

```json
{
  "name": "typescript-react",
  "description": "React + TypeScript signals for review-pro reviewers",
  "reviewers": ["security", "correctness", "craft", "frontend", "a11y", "performance", "api-contract", "tests"]
}
```

## Packs shipped (v0.1)

- `typescript-react` — React + TypeScript
- `node` — Node.js server
