# Stack pack: ai-ml — backend
extends: core/skills/backend/SKILL.md

## Stack-specific signals
- LLM/model endpoint with no timeout, no retry cap, or no concurrency limit → one slow model call stalls workers / runaway cost.
- No input/output size cap (token count, image bytes) on a model endpoint → cost/DoS.
- Streaming response not backpressure-aware; partial/aborted streams leaving state inconsistent.
- Returning raw model errors / full provider errors (incl. leaked prompt) to clients; inconsistent error shapes.
- Sync blocking model call inside an async handler; or a long-running inference holding a request thread with no offload.
- Missing idempotency on a model-mutating endpoint (e.g. fine-tune submit, billed calls).

## Stack-specific remedies
- Bound every model call (timeout, max tokens, max concurrency, retry budget); stream with backpressure; centralize errors; offload heavy inference.

## Stack-specific severity guidance
- No timeout/concurrency cap on a billed model endpoint: High (cost/availability).
- Sync inference blocking an event loop: High.
- Raw provider error leaking prompt: Medium/High.
