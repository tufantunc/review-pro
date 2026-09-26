# Rule draft for this repository (measurement input, written before the measurement)

Co-change rules: when a file matching `when` changes, the files in `then` are expected to
change in the same pull request. `all` means every listed file; `any` means at least one.
`{pack}` binds to the same directory name on both sides.

Each rule carries its source:

- **documented**: the rule is already written in `CONTRIBUTING.md`, `stacks/CONTRIBUTING.md`,
  `docs/internals/releasing.md` or an ADR, with the date it was written.
- **post-miss**: written down after a known miss, or first written now because of one. These
  carry retro-fit risk: a rule written knowing the miss is expected to catch it.

| ID | when | then | mode | why | source |
|---|---|---|---|---|---|
| C1 | `docs-src/**` | `docs/index.html`, `docs/docs.html`, `docs/*/index.html`, `docs/*/docs.html` | any | `docs/` is generated from `docs-src/`; an unrebuilt site ships stale on the next push to main | documented: CONTRIBUTING.md, "Before you open a PR" (since the site existed, 2026-06) |
| C2 | `stacks/{pack}/*` except `stacks/{pack}/manifest.json` | `stacks/{pack}/manifest.json` | all | `update` re-copies a pack only when its manifest `version` changed | documented: stacks/CONTRIBUTING.md, "How packs reach users" (since #71, 2026-09-23) |
| C3 | `cli/package.json` | `cli/package-lock.json`, `.claude-plugin/marketplace.json`, `core/.claude-plugin/plugin.json`, `core/.codex-plugin/plugin.json`, `.cursor-plugin/plugin.json` | all | a release bumps six version fields across five files | documented: releasing.md step 1 (since #60, 2026-08-31); the `.cursor-plugin` target is post-miss (added in v1.4.0, #76) |
| C4 | `core/skills/**`, `core/agents/**`, `core/shared/**` | `docs/llms.txt` | all | llms.txt is hand-written and describes behaviour; no check reads it | documented: releasing.md step 3 (since #60); written after the v0.7.0 miss (#29), so post-miss for that case |
| C5 | `core/skills/**`, `core/agents/**`, `core/shared/**` | `cli/README.md` | all | the npm package page describes behaviour and lives outside `core/` | documented: releasing.md step 3 (since #60); post-miss for v0.7.0 |
| C6 | `manifest.json` | `README.md`, `docs/llms.txt`, `cli/README.md`, `cli/package.json`, `CONTRIBUTING.md`, `docs-src/i18n/*.json` | all | the reviewer roster and count are published in these files | documented: CONTRIBUTING.md "Adding a new reviewer" and the published-count guard (since #31, 2026-08-20); post-miss for v0.7.0 |
| C7 | `core/shared/output-schema.md` | `core/agents/*-reviewer.md` | any | agent bodies inline the schema; a rule added to the shared schema reaches reviewers only through the bodies | documented: ADR-0001 (recorded 2026-08-27, #46) |
| P1 | `core/skills/review-pro-synthesize/SKILL.md` | `core/shared/severity.md` | all | severity.md carries the shared verdict table the README points to | post-miss: v1.4.0 release review (#76) found it stale after #74 changed the verdict rule |

## Rule text as a reviewer would see it

Each rule also carries one sentence, the text the judgment step reads. For the measurement:

- C1: "A change to the site sources must be rebuilt into `docs/` in the same PR."
- C2: "A change to a stack pack's files must bump that pack's `manifest.json` version."
- C3: "A version change in `cli/package.json` must be mirrored in the lockfile and the four plugin manifests."
- C4: "A change to review-pro's behaviour must be reflected in `docs/llms.txt`, which no check reads."
- C5: "A change to review-pro's behaviour must be reflected in `cli/README.md`, which npm renders as the package page."
- C6: "A change to the reviewer roster must update every surface that states the count or lists the reviewers."
- C7: "A rule added to the shared output schema must be added to the reviewer agent bodies that inline it."
- P1: "A change to the verdict rule in synthesis must be reflected in `core/shared/severity.md`."
