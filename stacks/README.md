# Stack packs

Stack packs add **language/framework-specific signals** to a reviewer's core rubric (e.g. the security reviewer learns that `dangerouslySetInnerHTML` = XSS for React).

## How stacks work (per-repo, agent-native)

Stacks are installed **per repo** into `.review-pro/` — NOT bundled with the core plugin and NOT requiring any scripts at review time.

```
<your-repo>/.review-pro/
  typescript-react/
    manifest.json     { "name": "typescript-react", "reviewers": [...] }
    security.md
    correctness.md
    ...
  node/
    manifest.json
    ...
```

At review time the orchestrator (`review-pro` skill) does everything natively with its own tools:
1. `Glob .review-pro/*/manifest.json` → the repo's **active stacks**.
2. For each dispatched reviewer, `Read .review-pro/<stack>/<reviewer>.md` (if present) → the reviewer's **stack signals**.
3. Passes those as a `### Stack signals` section to the reviewer subagent, which auto-loads its core skill and applies the stack signals on top.

**No shell scripts, no env vars, no plugin-path resolution at review time.** If `.review-pro/` is empty, reviewers run core-only.

## Installing stacks

The intended path is a separate community CLI (separate repo/package):

```bash
npx review-pro            # interactive: select stacks for this repo
npx review-pro add node   # non-interactive
```

It writes the selected packs into `.review-pro/`. It supports arbitrary languages/frameworks — not only Node (`.NET`, Flutter, Go, Rust, …). That CLI lives in its own repo; this core repo only defines the `.review-pro/` convention the agent reads.

> Until the CLI ships, copy the packs you need manually: `cp -R stacks/<pack> <your-repo>/.review-pro/<pack>`.

## This repo's `stacks/` directory

`stacks/` here is the **canonical catalog / source of packs** plus working samples:
- `stacks/typescript-react/` — React + TypeScript
- `stacks/node/` — Node.js server

These double as the reference packs the (future) installer sources from, and as samples for contributors writing new packs. Commit new packs here; they flow out to repos via the installer.

## Pack file format

```markdown
# Stack pack: <stack> — <reviewer>
extends: core/skills/<reviewer>/SKILL.md

## Stack-specific signals
- concrete thing to flag in this stack

## Stack-specific remedies
- concrete fix in this stack

## Stack-specific severity guidance
- how this stack adjusts severity
```

Each pack dir has a `manifest.json` listing the reviewers it supplements. A pack only needs files for reviewers where it adds value (e.g. a `go` pack has no `frontend.md`).
