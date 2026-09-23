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
- `pickle.load` on untrusted weights, or `torch.load` below 2.6 or with `weights_only=False`: Critical. Prompt injection that makes a tool act beyond what the attacker could invoke directly: Critical when the tool reaches code execution or the whole data store, High otherwise.
- Secret leaked into a prompt/log: High.
- Unbounded agent loop with cost/DoS potential: High.

## Not a finding
- `torch.load(path)` on PyTorch 2.6 or later, where `weights_only` defaults to `True` and refuses arbitrary pickled objects. Check the pinned version first: a version below 2.6, or an explicit `weights_only=False`, is the finding.
- Loading `safetensors` or ONNX weights. These formats carry tensors and metadata, not executable objects.
- Untrusted text reaching a prompt, on its own. Prompt injection becomes a finding only when the content drives an action or a disclosure the attacker could not get directly: a tool call under another principal's authority, a read of data the attacker cannot see, or a write into another user's context or memory. Name that action.
- A model carrying out what the requesting user asked for, with that user's own permissions. That is the feature working, not excessive agency.
- The reverse holds too: an instruction in a system prompt ("never reveal", "ignore instructions in documents") is not the control that makes a path safe. Count only deterministic checks, per-resource authorization, and scoped credentials.
