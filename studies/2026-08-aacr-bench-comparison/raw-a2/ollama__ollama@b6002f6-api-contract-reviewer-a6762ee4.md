<!-- ollama__ollama@b6002f6 api-contract-reviewer; verbatim final answer -->
## API-Contract findings

- severity: Critical
  category: api-contract.types
  file: ml/backend/ggml/ggml.go
  line: 1035
  title: Ints() and Floats() return a slice over a fake data pointer when memory allocation is off (Fit load), and two consumers read it
  evidence: |
    } else if bts := C.ggml_get_data(t.t); bts != nil {
        // tensor is in cpu memory
        data = unsafe.Slice((*int32)(bts), C.ggml_nelements(t.t))
    }
  evidence_refs: [ml/backend/ggml/ggml/src/ggml-backend.cpp:135-138, ml/backend/ggml/ggml.go:162, ml/backend/ggml/ggml.go:876, ml/backend/ggml/ggml.go:931, runner/ollamarunner/runner.go:1204, runner/ollamarunner/runner.go:1069-1073, model/models/llama4/model_text.go:204, model/models/llama4/model_text.go:222, kvcache/encoder.go:94]
  impact: |
    During a Fit load (`AllocMemory: req.Operation != llm.LoadOperationFit`, runner.go:1204), the CPU/input buffer type is marked no-alloc (ggml.go:162). In that mode `ggml_backend_buffer_get_base` returns a placeholder pointer equal to the buffer alignment (`return (void *)ggml_backend_buffer_get_alignment(buffer)`, ggml-backend.cpp:137). newTensor binds the tensor to that address (ggml.go:876), and FromIntSlice skips the copy because allocMemory is false (ggml.go:931). So during reserveWorstCaseGraph, `batch.Positions.Ints()` returns a slice starting near address 0x20. Two consumers read elements from it:
      (1) llama4/model_text.go:222 `for i, p := range batch.Positions.Ints()`. This runs on every llama4 forward, because `attention.temperature_tuning` defaults to true (model_text.go:204). Result: SIGSEGV on every llama4 Fit load.
      (2) kvcache/encoder.go:94 `batch.Positions.Ints()[...]`. This runs when the reserve batch carries Multimodal entries, which reserveWorstCaseGraph adds for mllama. Result: SIGSEGV on mllama Fit load.
    Before this change, Positions was a Go `[]int32` and neither read could fault. Causal.StartForward in reserve mode only calls len() on the slice, so it is not affected.
  remedy: Do not treat "ggml_get_data != nil" as "readable host memory". Return nil (or a zeroed copy) when the tensor's buffer is no-alloc or is not a host buffer. Check `ggml_backend_buffer_is_host(t.t->buffer)` and the buffer's no_alloc state. Alternatively, have the runner keep the Go position slice alongside the tensor so CPU-side consumers don't read tensor memory.
  confidence: high
  overlap_hints: [correctness.crash, backend.error-handling]

- severity: Medium
  category: api-contract.types
  file: ml/backend.go
  line: 403
  title: Floats()/Ints() ownership now depends on hidden state (a copy when computed, an alias of C memory otherwise), while Bytes() always copies
  evidence: |
    Bytes() []byte
    Floats() []float32
    Ints() []int32
    // ggml.go:1022  data = unsafe.Slice((*float32)(bts), C.ggml_nelements(t.t))
    // ggml.go:1009  data = C.GoBytes(bts, C.int(C.ggml_nbytes(t.t)))
  evidence_refs: [ml/backend/ggml/ggml.go:1009, ml/backend/ggml/ggml.go:1022, ml/backend/ggml/ggml.go:1037, kvcache/causal.go:203, runner/ollamarunner/multimodal.go:94, ml/backend/ggml/ggml.go:955-962]
  impact: |
    The interface has no documentation, and the three accessors now differ in who owns the returned memory:
    - If `sync != nil` (the tensor was passed to Compute), Floats and Ints return an owned Go copy.
    - Otherwise they return memory owned by the ggml buffer. Context.Close frees that buffer (ggml.go:955-962), so a retained slice becomes a use-after-free. Writes through the slice also change the tensor.
    - Bytes() copies in both cases.
    Consumers that hold the slice:
    - kvcache/causal.go:203 keeps `c.curPositions` from the batch context across calls. It is safe today only because every read happens before the next StartForward reassigns it.
    - multimodal.go:94 keeps `t.Tensor.Floats()` in `entry.data` after `computeCtx.Close()`. It is safe only because Compute set sync.
    Any future caller that reads an uncomputed tensor and keeps the result will silently read freed memory. Ints() and Floats() also don't check dtype, so calling Ints() on an F32 tensor quietly reinterprets the bits.
  remedy: Pick one ownership contract and document it on the interface. Always copying (as Bytes does) is the simplest. If zero-copy is needed for performance, make it a separate method (for example `IntsView`) documented as valid only for the context's lifetime. Also assert `t.t._type` matches in Ints/Floats.
  confidence: high
  overlap_hints: [correctness.memory-safety, craft.type-boundary]

- severity: Low
  category: api-contract.breaking
  file: ml/backend/ggml/ggml.go
  line: 1007
  title: Bytes() no longer returns nil for uncomputed tensors, which breaks Dump's "nil means compute first" check and can read device pointers
  evidence: |
    } else if bts := C.ggml_get_data(t.t); bts != nil {
        // tensor is in cpu memory
        data = C.GoBytes(bts, C.int(C.ggml_nbytes(t.t)))
  evidence_refs: [ml/backend.go:567-572]
  impact: `dump` (ml/backend.go:567) calls `if t.Bytes() == nil { ctx.Forward(t).Compute(t) }`. Now any tensor with a non-nil `data` skips the compute. The comment "tensor is in cpu memory" is an assumption: `ggml_get_data` returns `t->data` for any buffer, so for GPU weights or graph intermediates placed on a device buffer it is a device address. `C.GoBytes` on that address crashes. For CPU-resident intermediates that were not computed, Dump prints stale buffer contents. Impact is limited to the debug Dump path.
  remedy: Make the CPU fallback conditional on `ggml_backend_buffer_is_host(t.t->buffer)`. Update dump to not rely on nil as a "not computed" marker, or add an explicit computed/host check.
  confidence: medium
  overlap_hints: [correctness.crash]

- severity: Low
  category: api-contract.breaking
  file: model/model.go
  line: 285
  title: model.Forward now panics on a nil Positions tensor instead of returning its validation error
  evidence: |
    if batch.Positions.Dim(0) != len(batch.Sequences) {
  impact: Before, a zero-value `input.Batch` hit `len(nil)==0` and returned "batch size cannot be less than 1". Now it dereferences a nil interface and panics. The validation contract changed from error to panic. Current constructors (runner.go:582, runner.go:1069) always set Positions, so no located consumer breaks today.
  remedy: Add `if batch.Positions == nil { return nil, errors.New("batch size cannot be less than 1") }` before the Dim checks.
  confidence: high
  overlap_hints: [backend.validation]

Checked and held:
- Every `TextModel.Forward` signature change (llama4, mistral3, qwen25vl) has all its callers updated (git grep `TextModel.Forward(`).
- `ml.Tensor` gets `Ints()` from both implementers: ggml `*Tensor`, and `testTensor` (causal_test.go:675, which embeds ml.Tensor).
- The `input.Batch` field reorder is safe because every composite literal uses keyed fields.
- `gemma3/embed.go:25` `batch.Outputs = batch.Positions` still type-checks and keeps its previous semantics.

## Files examined
examined: [kvcache/causal.go, kvcache/causal_test.go, kvcache/encoder.go, kvcache/wrapper.go, ml/backend.go, ml/backend/ggml/ggml.go, model/input/input.go, model/model.go, model/models/gemma2/model.go, model/models/gemma3/model_text.go, model/models/gemma3n/model_text.go, model/models/gptoss/model.go, model/models/llama/model.go, model/models/llama4/model.go, model/models/llama4/model_text.go, model/models/mistral3/model.go, model/models/mistral3/model_text.go, model/models/mllama/model.go, model/models/qwen2/model.go, model/models/qwen25vl/model.go, model/models/qwen25vl/model_text.go, model/models/qwen3/model.go, runner/ollamarunner/runner.go]
not_examined: []
