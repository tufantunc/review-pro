<!--
Title: use Conventional Commits — feat(cli): …  fix(reviewers): …  docs(site): …
Release notes are generated from history, so the title becomes the changelog line.
-->

## What and why

<!-- What changes, and what problem it solves. Link the issue: Closes #123 -->

## Type

- [ ] Reviewer rubric — sharpened, added, or corrected a signal
- [ ] Stack pack — new pack or new signals
- [ ] CLI — command, flag, or install behavior
- [ ] Orchestration — triage dispatch or synthesis rules
- [ ] Docs / site
- [ ] CI / build / security

## Checks

```bash
./scripts/validate.sh
bash scripts/validate.test.sh
cd cli && npm test
```

- [ ] `./scripts/validate.sh` passes
- [ ] `bash scripts/validate.test.sh` passes
- [ ] `cd cli && npm test` passes (if `cli/` changed)
- [ ] Rebuilt and committed `docs/` via `node scripts/build-site.js` (if `docs-src/` changed)

## If this touches reviewers or packs

- [ ] Signals are **concrete** — they name a real API/construct and the failure it causes
- [ ] Signals are **stack-specific**, not a rehash of the core rubric (packs only)
- [ ] Verified against the real stack — no invented APIs or misremembered behavior
- [ ] Smoke-tested on a real diff, and the new signal actually surfaced

<!-- Paste the finding it produced, if you have it. Real evidence beats a checkbox. -->

## If this touches the CLI

- [ ] Tested on more than one target (`opencode` / `claude-code` / `cursor` / `codex`)
- [ ] `init` and `uninstall` stay inverses of each other
- [ ] `manifest.json` updated if skills or agents changed

## Notes for the reviewer

<!-- Anything you're unsure about, or deliberately left out of scope. -->
