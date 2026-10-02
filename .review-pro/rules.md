# Review rules

Rules review-pro checks on every change to this repository. Each is read from the merge base,
so a change to this file applies from the next change. The format and the review behaviour are
described in the README's "Repository rules" section; the measurement these rules come from is
`studies/2026-09-repo-rules-spike/`.

## R1: the site is rebuilt with its sources
- when: `docs-src/**`
- then: `docs/index.html`, `docs/docs.html`, `docs/*/index.html`, `docs/*/docs.html` (any)
- rule: A change to the site sources must be rebuilt into `docs/` in the same change.

Why: `docs/` is generated and deploys on push to main; an unrebuilt change ships stale. CI also
checks the drift; this rule names it in the review. Source: CONTRIBUTING.md.

## R2: a changed pack bumps its version
- when: `stacks/{pack}/*.md`
- then: `stacks/{pack}/manifest.json`
- rule: A change to a stack pack's files must bump that pack's `manifest.json` version.

Why: `update` re-copies a pack only when its version changed, so an unbumped edit never
reaches existing installs, and nothing else checks it. Source: stacks/CONTRIBUTING.md.

## R3: version fields move together
- when: `cli/package.json`
- then: `cli/package-lock.json`, `.claude-plugin/marketplace.json`, `core/.claude-plugin/plugin.json`, `core/.codex-plugin/plugin.json`, `.cursor-plugin/plugin.json`
- rule: A change to the `version` field of `cli/package.json` must be mirrored in the lockfile and every plugin manifest; a dependency or description change needs none of them.

Why: `.cursor-plugin/plugin.json` sat at 0.1.0 for seven releases and the lockfile at 0.7.0 for
three. Source: docs/internals/releasing.md, step 1.

## R4: llms.txt follows behaviour
- when: `core/skills/**`, `core/agents/**`, `core/shared/**`
- then: `docs/llms.txt`
- rule: A change to what review-pro does, as a reader of `docs/llms.txt` would describe it, must be reflected there; no check reads that file.

Why: llms.txt described the wrong reviewer count after v0.7.0 and missed the verifier until the
release after #74. Source: docs/internals/releasing.md, step 3.

## R5: the npm page follows behaviour
- when: `core/skills/**`, `core/agents/**`, `core/shared/**`
- then: `cli/README.md`
- rule: A change to what review-pro does, as the npm package page describes it, must be reflected in `cli/README.md`.

Why: the package page lives outside `core/`, where attention goes, and went stale in v0.7.0 and
after #74. Source: docs/internals/releasing.md, step 3.

## R6: the roster is published everywhere
- when: `manifest.json`
- then: `README.md`, `docs/llms.txt`, `cli/README.md`, `cli/package.json`, `CONTRIBUTING.md`, `docs-src/i18n/en.json`, `docs-src/i18n/de.json`, `docs-src/i18n/fr.json`, `docs-src/i18n/nl.json`, `docs-src/i18n/tr.json`, `docs-src/i18n/hi.json`, `docs-src/i18n/zh.json`
- rule: A change to the reviewer roster must update every surface that states the count or lists the reviewers.

Why: the count went stale in llms.txt and, spelled as a word, in seven locales. The validator's
published-count guard checks the count; this rule covers the rest of what a roster change
touches. The locales are listed one by one because a glob in `then` is satisfied by any one
matching file. Source: CONTRIBUTING.md, "Adding a new reviewer".

## R7: a schema rule reaches the agent bodies
- when: `core/shared/output-schema.md`
- then: `core/agents/*-reviewer.md` (any)
- owner: correctness
- rule: A rule added to the shared output schema must also be added to the reviewer agent bodies that inline it.

Why: agent bodies do not load `core/shared/`, so a rule only in the shared schema never reaches
a running reviewer. Source: ADR-0001.

## R8: severity.md follows the verdict rule
- when: `core/skills/review-pro-synthesize/SKILL.md`
- then: `core/shared/severity.md`
- rule: A change to the verdict rule in synthesis must be reflected in `core/shared/severity.md`.

Why: #74 changed the verdict rule and severity.md kept the old table until the v1.4.0 release
review caught it.

## R9: a removed or softened instruction is stated
- when: `core/skills/**`, `core/agents/**`, `core/shared/**`
- owner: correctness
- rule: A change that removes or softens an instruction (a must, never, always or stop, or a stated guarantee) must say so, and why, in its PR description or commit message.

Why: the validator no longer pins the sentences of a rule, so deleting or qualifying one passes CI;
this rule is what catches it. Source: ADR-0013.
