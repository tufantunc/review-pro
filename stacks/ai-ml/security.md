# Stack pack: ai-ml — security
extends: core/skills/security/SKILL.md

## Stack-specific signals
- `torch.load(...)`, `pickle.load`, `joblib.load`, `numpy.load`, `tf.saved_model.load` on an untrusted model/checkpoint file → arbitrary code execution. Prefer `weights_only=True` (torch>=2.0) / safetensors / ONNX.
- **Prompt injection** in LLM apps: untrusted text concatenated into the system prompt, or treated as an instruction (`messages=[{"role":"system","text": UNTRUSTED}]`, f-string prompt templates with user input).
- **Tool/function-call abuse**: LLM-controlled tool selection executes privileged actions (DB write, shell, HTTP) without an allowlist, confirmation, or sandbox.
- Secrets/API keys passed into prompts, embeddings, or logged alongside completions.
- Unbounded/recursive agent loops (agent can call itself or spawn agents with no depth/cost cap) → runaway cost/DoS.
- Returning raw model errors / full stack traces / internal prompts to users.
- Fine-tuning on untrusted data without sanitization; loading datasets that execute on parse (e.g. malicious `pickle` inside a "dataset").

## Stack-specific remedies
- Load model weights with `weights_only=True`/safetensors; never `pickle`/`torch.load` untrusted files.
- Separate instructions from data (structured tool input, not free-text prompts); treat model output as untrusted.
- Allowlist + confirm privileged tool calls; bound agent depth/cost; sanitize logs.

## Stack-specific severity guidance
- `torch.load`/`pickle.load` on untrusted weights, or prompt injection that reaches a privileged tool: Critical.
- Secret leaked into a prompt/log: High.
- Unbounded agent loop with cost/DoS potential: High.
