# Security Policy

review-pro installs skills and subagents into your agent tool's home directory and reads your repository's diff. That makes both the published npm package and the installed markdown a supply-chain surface worth reporting bugs against.

## Supported versions

Only the latest published version of the `review-pro` npm package receives security fixes. There are no long-term support branches.

| Version | Supported |
|---|---|
| latest `0.x` | ✅ |
| older `0.x` | ❌ — upgrade first |

## Reporting a vulnerability

**Do not open a public issue for a security report.**

Use GitHub's [private vulnerability reporting](https://github.com/tufantunc/review-pro/security/advisories/new) — it creates a private advisory only the maintainers can see.

Please include:

- What the issue is and the impact you believe it has.
- Reproduction steps, ideally with the exact `npx review-pro` command or repository state.
- The version (`npx review-pro --version`), your platform target (opencode / Claude Code / Cursor / Codex), and OS.

### What to expect

- **Acknowledgement:** within 7 days.
- **Assessment:** within 14 days, with a severity call and a rough fix timeline.
- **Fix + disclosure:** coordinated. The advisory is published once a fixed version is on npm, crediting you unless you prefer otherwise.

This is a volunteer-maintained project, not a commercial product with an on-call rotation. There is no bug bounty.

## In scope

- Arbitrary file write, path traversal, or writes outside the documented install targets during `init`, `add`, `remove`, or `uninstall`.
- Arbitrary code execution triggered by installing or running the CLI.
- Compromise of the release pipeline (`.github/workflows/publish.yml`), the published artifact, or the catalog snapshot in `cli/catalog/`.
- Prompt-injection paths in the core skills or stack packs that would cause a reviewer subagent to exfiltrate repository contents or execute unintended commands.

## Out of scope

- **Missed findings.** A reviewer failing to flag a real bug is a quality issue, not a vulnerability — open a normal issue.
- **False positives.** Same: open a normal issue so the signal can be sharpened.
- Vulnerabilities in the code *being reviewed* — that's the user's repository.
- Vulnerabilities in the host agent tool (opencode, Claude Code, Cursor, Codex) — report those upstream.
- Issues requiring an already-compromised local machine or an attacker who can already write to the user's agent home directory.

## Supply-chain posture

- Published from a tag-triggered GitHub Actions workflow, never from a laptop.
- npm [provenance](https://docs.npmjs.com/generating-provenance-statements) attestation on every release, tying the artifact to the building workflow.
- All GitHub Actions pinned to full commit SHAs, kept current by Dependabot.
- CodeQL (`security-extended`) and OpenSSF Scorecard run on every push and weekly.
- Two runtime dependencies: `commander` and `@inquirer/prompts`.
