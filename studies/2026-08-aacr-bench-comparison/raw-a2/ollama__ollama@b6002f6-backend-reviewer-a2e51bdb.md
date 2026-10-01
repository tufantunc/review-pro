<!-- ollama__ollama@b6002f6 backend-reviewer; verbatim final answer -->
## Backend findings

- severity: High
  category: backend.error-handling
  file: ml/backend/ggml/ggml.go
  line: 1035
  title: New Ints() CPU fallback returns a slice over a fake pointer in no-alloc (Fit) mode, and reserve-time callers read it
  evidence: |
    } else if bts := C.ggml_get_data(t.t); bts != nil {
        // tensor is in cpu memory
        data = unsafe.Slice((*int32)(bts), C.ggml_nelements(t.t))
    }
  evidence_refs:
    - ml/backend/ggml/ggml/src/ggml-backend.cpp:133
    - ml/backend/ggml/ggml.go:162
    - ml/backend/ggml/ggml.go:931
    - runner/ollamarunner/runner.go:1204
    - runner/ollamarunner/runner.go:1069
    - model/models/llama4/model_text.go:222
    - kvcache/encoder.go:94
    - llm/server.go:709
  impact: |
    Every model load starts with LoadOperationFit (llm/server.go:709), which sets AllocMemory=false (runner.go:1204). That calls ggml_backend_buft_set_alloc(false) on the CPU buffer type, which is also the Input() buffer type.
    - In that mode `FromIntSlice` writes no data (ggml.go:931, `if c.b.allocMemory && len(s) > 0`).
    - `ggml_backend_buffer_get_base` returns a non-NULL placeholder: `return (void *)ggml_backend_buffer_get_alignment(buffer)` (ggml-backend.cpp:136). So tensor->data is a small fake address such as 0x20.
    - Ints() only checks `bts != nil`. It builds a slice of full length over that address and returns no error.
    - `reserveWorstCaseGraph` now passes `batch.Positions = ctx.Input().FromIntSlice(...)` (runner.go:1069) into code that reads the values:
      - llama4 `for i, p := range batch.Positions.Ints()` (model_text.go:222). `attention.temperature_tuning` defaults to true.
      - `EncoderCache.StartForward` `batch.Positions.Ints()[...]` (encoder.go:94). mllama reaches this when the worst-case batch includes the encoded image.
    - The read hits a low address. Go turns that into a nil-dereference runtime panic. allocModel's recover turns it into a load error ("invalid memory address or nil pointer dereference").
    - Result: under Fit, llama4 and likely mllama can no longer load.
    - Before this change, positions were a Go []int32 and never went through tensor readback.
    - The same unguarded fallback in Bytes() (line 1007) passes the fake pointer to C.GoBytes. That is a C-level fault the runtime cannot recover from (reached through ml.Dump).
  remedy: |
    - Make the readback methods refuse no-alloc tensors: check `t.b.allocMemory` (or `tensor->buffer` no_alloc) before the `ggml_get_data` branch, and return nil (or panic with a clear error).
    - In the runner, keep the host-side `[]int32` positions and pass them to cache and model code that needs values (for example, add them to input.Batch next to the tensor). Then reserve-time code does not read tensor memory it never wrote.
    - Add a Fit-mode reserve test for llama4 and mllama.
  confidence: high
  overlap_hints: [correctness.error-path, correctness.cross-file]

- severity: Medium
  category: backend.boundary
  file: ml/backend/ggml/ggml.go
  line: 1037
  title: Ints()/Floats() CPU branch returns C-owned memory while the sync branch and Bytes() return copies
  evidence: |
    data = unsafe.Slice((*float32)(bts), C.ggml_nelements(t.t))
    ...
    data = unsafe.Slice((*int32)(bts), C.ggml_nelements(t.t))
  evidence_refs:
    - ml/backend/ggml/ggml.go:1023
    - ml/backend/ggml/ggml.go:1009
    - ml/backend/ggml/ggml.go:959
    - kvcache/causal.go:203
  impact: |
    The `ml.Tensor` interface now has two meanings depending on where the tensor lives:
    - After compute, Ints()/Floats() return a Go-owned copy.
    - For CPU tensors, they return memory that `Context.Close()` frees (`C.ggml_backend_buffer_free`).
    - Bytes() copies in both cases (GoBytes).
    `Causal.StartForward` keeps the result in `c.curPositions`, a struct field that lives beyond the batch context. Today it is only read inside StartForward. But any later read (a new Remove/CanResume path, trace logging) or any caller that writes to the returned slice would read freed memory or silently change the input tensor. Neither the interface nor the call site shows that the slice is borrowed.
  remedy: Return a copy in the CPU branch (for example, `copy` into a `make([]int32, n)`), matching Bytes() and the sync branch. Or document on `ml.Tensor` that the result is borrowed and only valid while the context is open, and have Causal copy what it keeps.
  confidence: medium
  overlap_hints: [correctness.lifetime, api-contract.semantics]

## Files examined
examined: [kvcache/causal.go, kvcache/causal_test.go, kvcache/encoder.go, kvcache/wrapper.go, ml/backend.go, ml/backend/ggml/ggml.go, model/input/input.go, model/model.go, model/models/gemma2/model.go, model/models/gemma3/model_text.go, model/models/gemma3n/model_text.go, model/models/gptoss/model.go, model/models/llama/model.go, model/models/llama4/model.go, model/models/llama4/model_text.go, model/models/mistral3/model.go, model/models/mistral3/model_text.go, model/models/mllama/model.go, model/models/qwen2/model.go, model/models/qwen25vl/model.go, model/models/qwen25vl/model_text.go, model/models/qwen3/model.go, runner/ollamarunner/runner.go]
not_examined: []
