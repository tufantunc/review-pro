# Stack pack: ai-ml — security
extends: core/skills/security/SKILL.md

## Stack-specific signals
- `torch.load(...)`, `pickle.load`, `joblib.load`, `numpy.load`, `tf.saved_model.load` on an untrusted model/checkpoint file → arbitrary code execution. Prefer `weights_only=True` on torch 2.6 or later (earlier versions can be bypassed, CVE-2025-32434) / safetensors.
- `from_pretrained(..., trust_remote_code=True)` on a model id or repository a lower-trust actor can influence → imports and runs that repository's Python code, whatever format the weights are in.
- **Prompt injection** in LLM apps: untrusted text concatenated into the system prompt, or treated as an instruction (`messages=[{"role":"system","text": UNTRUSTED}]`, f-string prompt templates with user input).
- **Tool/function-call abuse**: LLM-controlled tool selection executes privileged actions (DB write, shell, HTTP) without an allowlist, confirmation, or sandbox.
- Secrets/API keys passed into prompts, embeddings, or logged alongside completions.
- Unbounded/recursive agent loops (agent can call itself or spawn agents with no depth/cost cap) → runaway cost/DoS.
- Returning raw model errors / full stack traces / internal prompts to users.
- Fine-tuning on untrusted data without sanitization; loading datasets that execute on parse (e.g. malicious `pickle` inside a "dataset").
- `TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD` set anywhere in the runtime environment (a Dockerfile, a CI job) → every `torch.load` that does not pass `weights_only` explicitly falls back to full pickle loading; so does passing `pickle_module=`.
- `onnx.load` of an untrusted model with its external data on onnx below 1.21.0 → `../` paths, symlinks, or hardlinks in `external_data` read files outside the model directory (CVE-2024-27318, CVE-2026-27489, CVE-2026-34446, CVE-2026-34447). Whether a model has external data is the attacker's choice.

## Stack-specific remedies
- Load model weights with `weights_only=True`/safetensors; never `pickle`/`torch.load` untrusted files.
- Separate instructions from data (structured tool input, not free-text prompts); treat model output as untrusted.
- Allowlist + confirm privileged tool calls; bound agent depth/cost; sanitize logs.

## Stack-specific severity guidance
- `pickle.load` on untrusted weights, or `torch.load` below 2.6 or with `weights_only=False`: Critical. Prompt injection that makes a tool act beyond what the attacker could invoke directly: Critical when the tool reaches code execution or the whole data store, High otherwise.
- Secret leaked into a prompt/log: High.
- Unbounded agent loop with cost/DoS potential: High.
