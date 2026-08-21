# Reviewer anti-derailment directive (maintainer reference)

> **Status:** This file is **maintainer documentation** of *why* every `*-reviewer`
> agent body is written the way it is. It is **not** relied on for model behavior —
> the operative directive is embedded directly in each agent body in
> `core/agents/*-reviewer.md`, because the body is what must dominate trailing
> runtime boilerplate. Subagents do not auto-load this file.

## Problem these bodies solve

The `*-reviewer` subagents intermittently "derailed" — they emitted
system-prompt/boilerplate text or ran an unrelated skill instead of performing
their review, producing **zero findings and zero tool calls**. A correct,
complete task prompt was sent both times, and re-running the same task through a
generic general-purpose agent worked perfectly. So the defect was specific to
how the `*-reviewer` agent types are set up, not the task prompt, the
orchestrator, or the core skills.

### Failure mode (a) — parroting runtime boilerplate
A reviewer (observed: `frontend-reviewer`) returned a fragment of the
**platform-assembled system prompt** — the trailing "on-demand skills / MCP
servers" inventory — instead of a review. With zero tool calls.

Root cause: the platform appends boilerplate (on-demand skill inventory, MCP
server list, tool catalog) **after** the agent body when assembling the
subagent's system prompt. The original reviewer body was ~10 lines of soft,
descriptive prose — too thin to anchor the model, so its attention latched onto
the trailing, completable-looking boilerplate and produced a continuation of it.

### Failure mode (b) — activating an unrelated skill
A reviewer (observed: `api-contract-reviewer`) emitted a *different* skill's
prompt ("Please review the current git branch for security vulnerabilities…")
and ran `security` instead of its declared `api-contract` skill. With zero tool
calls.

Root cause: the model, given a thin body and a list of other on-demand skills in
its context, chose to invoke a name/topic-adjacent skill (`security`) instead of
staying in its lane. API contracts are auth-adjacent, which made the drift
plausible to an un-anchored model. **This was not a frontmatter misresolution** —
`loads_skill: api-contract` / `skills: [api-contract]` was and is correct
(verified by `scripts/validate.sh`, which enforces `skills:` ⊇ `loads_skill` and
that `loads_skill` points to an existing skill dir). It is a runtime model-choice
problem.

## Editable vs runtime boundary

| Surface | Editable here? | Notes |
|---|---|---|
| `core/agents/*-reviewer.md` body | **Yes** | The agent's instruction body — the primary mitigation lever. |
| `core/agents/*-reviewer.md` frontmatter (`loads_skill`, `skills`) | **Yes** | Determines declared skill resolution. Already correct; validator guards it. |
| `core/skills/*/SKILL.md` rubrics | **Yes** | The review methodology. Fine as-is; auto-loaded by the platform. |
| `manifest.json` (agent → skill map) | **Yes** | Source of truth for which agent loads which skill. Already correct. |
| Platform's system-prompt assembly | **No (runtime/harness-owned)** | The trailing on-demand-skills inventory, MCP-server list, and tool catalog are appended by the platform, not by anything in this repo. The phrase "skills that only trigger when name" is **not** present in any file here — it is injected at runtime. We cannot remove it; we can only make the agent body strong enough to dominate it. |
| How/where the auto-loaded core skill is injected (system vs user msg) | **No (runtime/harness-owned)** | Affects anchoring strength but is outside our control. |

## The directive (what every reviewer body now embeds)

Each `*-reviewer.md` body is a firm, self-contained, imperative instruction with
these load-bearing sections, in order:

1. **Identity & mandate** — names the ONE concern; states the sole job (review
   `### Changed file contents`, return findings or an explicit "no findings"
   line); rejects the "general assistant" framing.
2. **Skill discipline (critical)** — declares the ONE core skill and explicitly
   forbids activating/invoking/loading any other skill, **naming the likely
   trap** for that reviewer (e.g. `api-contract-reviewer` names `security`;
   `frontend-reviewer` names `a11y`/`performance`; `backend-reviewer` names
   `security`/`db`).
3. **Anti-derailment (critical)** — labels trailing skills/MCP/tool text as
   runtime boilerplate and forbids echoing/continuing/summarizing/
   acknowledging it; forbids capabilities/help messages; imposes a **behavioral
   floor** (no zero-tool-call AND zero-finding output).
4. **Work** — the concrete steps, preserving each reviewer's specific
   verification semantics from the original body.
5. **Output schema** — embedded inline (not just referenced) so the model never
   has to "find" it.
6. **Final reminder** — terminal restatement: output is findings or the single
   "no findings" line; anything else is a failure.

## Residual limitation (not fully fixable from here)

Because the boilerplate is appended by the runtime **after** the agent body and
is outside this repo's control, no body edit can *guarantee* the model never
drifts under all conditions (model attention is probabilistic). The directive
above is the **strongest mitigation available within the editable surface**: it
raises the bar sharply by making the body imperative, self-contained, and
explicit about both failure modes, with a behavioral floor that makes a silent
zero-output derailment visibly non-compliant. The structural frontmatter guard
(`loads_skill`/`skills` validated by `scripts/validate.sh`) ensures the
*declared* resolution can never pull in a name-adjacent skill; the body guard
addresses the *runtime model-choice* drift.

If derailment is ever observed again after this change, the next lever is
runtime/harness-owned (e.g. a platform option to suppress the trailing
on-demand-skills/MCP inventory in subagent system prompts), which is outside the
scope of this plugin.
