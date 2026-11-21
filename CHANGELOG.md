# Changelog

What changed in each release, for the people who run review-pro. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow the policy in
[docs/internals/releasing.md](docs/internals/releasing.md). Releases before 1.6.0 are described
in their [GitHub release notes](https://github.com/tufantunc/review-pro/releases).

## [1.6.1] - 2026-11-21

### Changed
- **The installer CLI now declares the Node versions it runs on.** `engines.node` said `>=18`,
  but the installer's prompt library (`@inquirer/prompts` 8.8) needs Node 22.22.2 or later, 24.15
  or later, or 26 or later, and the previous release of it already excluded Node 18. The package,
  its README and the site FAQ now say so. The plugin itself is unchanged and still needs no Node.
- Dependency updates: `@inquirer/prompts` 8.8.0 and `commander` 15.1.0.

## [1.6.0] - 2026-11-16

### Added
- **Configurable base branch.** The base is now the invocation's argument, else `base` in
  `.review-pro/config.json` read from the default branch, else the default branch `origin/HEAD`
  names, else `main` or `master`. A repository that merges into an integration branch such as
  `development` names it once, and no installed file has to be edited. The config is read from
  the default branch, never the branch under review, so a change cannot choose its own base; a
  configured name that does not resolve or that a tag shadows stops the review. A change that
  edits the file is sent to `security`. The report gains a `Base:` line saying which source chose
  the base, and the dispatch plan a `base_source` key. `scripts/review.sh prep` prints
  `BASE_SOURCE:`. ([ADR-0014](docs/internals/adr/0014-read-the-base-from-the-default-branch.md))
- The validator rejects a repository path (`core/shared/`) or a platform install path
  (`~/.claude/`) anywhere under `core/`.

### Changed
- **Package files are named relative to the install.** Skills say where `shared/` and sibling
  skills are relative to their own directory, which holds for the npm installer on every
  platform and for the plugin layouts.
- **`craft`: a missed code-judo simplification is Medium and no longer blocks approval.** It is an
  improvement the change did not make, not a regression it introduced, so it requests changes;
  this also removes a conflict with synthesis, which lets a change that clearly improves the code
  be approved.
- **`spec` may search outside the diff** before reporting a requirement missing, as its agent body
  already told it to; the rubric and the context policy said otherwise.
- **Reviewer agent bodies use plain, reasoned instructions.** The `(critical)` headings and the
  capitalised `NOT` / `MUST` / `ONLY` are gone; every rule stays and now says why it exists.
  ([reviewer-directive.md](docs/internals/reviewer-directive.md#tone-v160))

### Removed
- `review-pro-triage-subagent` and `review-pro-synthesize-subagent`. The orchestrator runs triage
  and synthesis inline and never dispatched them, and their copies of the skills' inputs had
  already drifted. `init` and `uninstall` delete the copies an earlier release installed for
  Claude Code and opencode; Codex never received them. The `review-pro-triage` and `review-pro-synthesize` skills are
  unchanged as skills.

### Fixed
- Four pointers to `core/shared/…` in the orchestrator, triage and synthesis skills, which no
  install could open, now point at `shared/…`.
- The inline review path no longer tells the agent to read a rubric "from the plugin"; it names
  the sibling skill's path.
- The verification table in the synthesis skill was split by a paragraph, so its last three rows
  did not render as part of the table.
