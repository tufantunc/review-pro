# Canary: arm isolation under Amendment 2's flags (2026-09-28)

Three headless sessions in a throwaway two-commit repository, driven by `drive.py`. The driver
builds A1's argv from the fork's own helpers (`reviewers/claude.py` @ `73e9b3f`: MCP config,
findings system prompt, StopFailure hook settings) and adds
`--model claude-opus-5-5 --effort high --setting-sources project,local --strict-mcp-config`. It
uses `stream-json` output, where the adapter uses `json`, so the init event can be read.

| Session | What it is | `summary.json` holds |
|---|---|---|
| `P1-a1-probe` | A1's environment, probe prompt | The agents and skills listed; the replies to `Skill review-pro` (unknown) and `Agent correctness-reviewer` (not found); the two v1.4.0 marker strings (absent) |
| `P2-a1-codereview` | A1 running `/code-review <base>...<head>` | The same lists; its Bash `git diff` was denied (see `permission_denials`); findings arrived in stdout JSON, with no MCP call |
| `P3-a2-probe` | A2's environment: npm `review-pro@1.5.0` at project scope, with a marker line added to this copy only | review-pro listed once; the skill and agent markers returned; no v1.4.0 text |

The operator's user-scope install (review-pro v1.4.0 in `~/.claude/skills` and `~/.claude/agents`)
was not modified.
