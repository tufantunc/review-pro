# Contributing a stack pack

A **stack pack** adds language/framework-specific signals to a reviewer's core rubric. Packs live in `stacks/<pack>/` and ship in the catalog; users install them into a repo's `.review-pro/` via `npx review-pro`. This guide is how to add one.

## Before you write

- A pack only earns its place if it adds **concrete, stack-specific** signals the core rubric doesn't already cover. "Be careful with errors" is core territory; "`eval()` on dynamic input → RCE in CPython" is a python-pack signal.
- **Focused, not exhaustive.** Write a pack file only for reviewers where the stack genuinely adds value (see `typescript-react` with 8, `node` with 7). Skip reviewers where you'd be inventing thin signals.
- Verify signals against the real stack — no myths. If unsure, leave it out.

## Pack layout

```
stacks/<pack>/
  manifest.json          # name, version, description, reviewers
  <reviewer>.md          # one file per reviewer you cover
```

## `manifest.json`

```json
{
  "name": "python",
  "version": "0.1.0",
  "description": "Python signals for review-pro reviewers",
  "reviewers": ["security", "correctness", "craft", "backend", "db", "api-contract", "performance", "tests"]
}
```

Rules (enforced by `scripts/validate.sh`):
- `version` is semver (`x.y.z`).
- Every entry in `reviewers` must (a) match a core skill in `core/skills/` and (b) have a matching `<reviewer>.md` file in the pack dir.

## Pack file format

```markdown
# Stack pack: <pack> — <reviewer>
extends: core/skills/<reviewer>/SKILL.md

## Stack-specific signals
- concrete thing to flag, with the stack-specific mechanism

## Stack-specific remedies
- concrete fix using this stack's idioms/tools

## Stack-specific severity guidance
- how this stack adjusts severity (e.g. "XSS via mark_safe: Critical")
```

Keep each signal one line, concrete, and tied to a real API/construct in the stack.

## Authoring checklist

- [ ] `manifest.json` has `name`, `version`, `reviewers`.
- [ ] Every listed reviewer has a `<reviewer>.md` file.
- [ ] Each file has the three sections (signals / remedies / severity).
- [ ] Signals are stack-specific (not core-rubric rehash).
- [ ] `./scripts/validate.sh` passes.
- [ ] (Optional) smoke the composition: from a repo with `.review-pro/<pack>/`, run the review and confirm the new signals surface in findings.

## How packs reach users

1. `npm run build` (in `cli/`) bundles `stacks/` → `cli/catalog/`.
2. `npx review-pro` (interactive) or `add <pack>` copies `stacks/<pack>/` into the user's repo `.review-pro/<pack>/`.
3. At review time the orchestrator reads `.review-pro/<pack>/<reviewer>.md` and passes them to reviewers as `### Stack signals`.
