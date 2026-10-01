<!-- ollama__ollama@b6002f6 ai-antipatterns-reviewer; verbatim final answer -->
## AI-Antipatterns findings

- severity: High
  category: ai-antipatterns.hallucination
  file: ml/backend/ggml/ggml.go
  line: 1035
  title: The new CPU fallback treats any non-nil `ggml_get_data` pointer as readable host memory, but the vendored ggml says otherwise
  evidence: |
    } else if bts := C.ggml_get_data(t.t); bts != nil {
    	// tensor is in cpu memory
    	data = unsafe.Slice((*int32)(bts), C.ggml_nelements(t.t))
    }
  impact: |
    `C.ggml_get_data` and `C.GoBytes` both exist (ggml.h:805; GoBytes is standard cgo), so these are not invented symbols. What is wrong is the assumption in the comment: that a non-nil `tensor->data` means the tensor sits in CPU memory the Go side can read. The vendored ggml breaks that in two ways:
    (1) Fit mode. With `AllocMemory=false` (runner.go:1204, `req.Operation != llm.LoadOperationFit`), `ggml_backend_buft_set_alloc` is applied to the CPU input buffer type (ggml.go:162). `ggml_backend_buffer_get_base` then "return[s] a placeholder non-NULL pointer" equal to the buffer alignment (ggml-backend.cpp:135-137). `FromIntSlice` also skips writing the data (ggml.go:931). So `Ints()` builds a slice over an address like 0x20. Two paths added in this diff read from it during `reserveWorstCaseGraph` (runner.go:1070-1080):
      - kvcache/encoder.go:94, `batch.Positions.Ints()[...Index]`. It runs unconditionally, even when reserve is true, whenever the reserve batch has multimodal inputs (mllama).
      - model/models/llama4/model_text.go:222, `range batch.Positions.Ints()`. `attentionTemperatureTuning` defaults to true (model_text.go:204).
      Both crash with SIGSEGV during memory fitting.
    (2) Device memory. For tensors in GPU buffers, `tensor->data` holds a device address. `Bytes()` (line 1009, `GoBytes`) and `Floats()` (line 1023) now read it directly instead of returning nil. `ml.Dump` (ml/backend.go:567) relies on `t.Bytes() == nil` for tensors that have not been computed, and would now crash on them.
    The repo's ggml already has the right APIs: `ggml_backend_buffer_is_host` (ggml-backend.h:65) and `ggml_backend_tensor_get`, which works for any allocated buffer.
  remedy: |
    Don't infer that memory is host-readable from `tensor->data`. Only fall back when `t.t.buffer != nil` and `C.ggml_backend_buffer_is_host(t.t.buffer)` is true and the buffer is really allocated. Otherwise return nil, and copy with `ggml_backend_tensor_get` rather than aliasing. Also, in fit/reserve mode, callers that need real position values should not have to read them back from a tensor. Either keep the Go `[]int32` next to the tensor in `input.Batch`, or skip `Ints()` in encoder.go and llama4 when `reserve` is set.
  evidence_refs: [ml/backend/ggml/ggml.go:1007, ml/backend/ggml/ggml.go:1021, ml/backend/ggml/ggml.go:162, ml/backend/ggml/ggml.go:931, ml/backend/ggml/ggml/src/ggml-backend.cpp:135, ml/backend/ggml/ggml/include/ggml-backend.h:65, runner/ollamarunner/runner.go:1204, runner/ollamarunner/runner.go:1070, kvcache/encoder.go:94, model/models/llama4/model_text.go:222, ml/backend.go:567]
  confidence: high
  overlap_hints: [correctness.crash, correctness.side-effect, api-contract.semantics]

- severity: Low
  category: ai-antipatterns.ignored-convention
  file: ml/backend/ggml/ggml.go
  line: 1023
  title: The new fallbacks in `Floats()`/`Ints()` alias C memory while the matching `Bytes()` fallback copies it
  evidence: |
    data = C.GoBytes(bts, C.int(C.ggml_nbytes(t.t)))              // Bytes(): copy
    ...
    data = unsafe.Slice((*float32)(bts), C.ggml_nelements(t.t))   // Floats(): alias
    ...
    data = unsafe.Slice((*int32)(bts), C.ggml_nelements(t.t))     // Ints(): alias
  impact: |
    The three accessors now disagree about ownership. Their existing sync branch, which all three share, always returns a fresh Go-owned slice. That is what `ml.Tensor` callers depend on: for example, runner/ollamarunner/multimodal.go:94 keeps `t.Tensor.Floats()` in a long-lived cache. The new branches instead return a view into a ggml buffer that `Context.Close()` frees (ggml.go:961-962). Writing through the slice changes the tensor, and holding it after Close is a use-after-free. Nothing in the interface (ml/backend.go:402-404) signals the difference. Today `kvcache.Causal` keeps `c.curPositions` as exactly such an alias.
  remedy: Copy in every branch, as the existing branches do, e.g. `data = make([]int32, n); copy(data, unsafe.Slice((*int32)(bts), n))`, or read through `ggml_backend_tensor_get`. That gives all three accessors the same "returns an owned copy" contract.
  evidence_refs: [ml/backend/ggml/ggml.go:1009, ml/backend/ggml/ggml.go:961, runner/ollamarunner/multimodal.go:94, kvcache/causal.go:203]
  confidence: medium
  overlap_hints: [correctness.lifetime, craft.boundary]

## Files examined
examined: [kvcache/causal.go, kvcache/causal_test.go, kvcache/encoder.go, kvcache/wrapper.go, ml/backend.go, ml/backend/ggml/ggml.go, model/input/input.go, model/model.go, model/models/gemma2/model.go, model/models/gemma3/model_text.go, model/models/gemma3n/model_text.go, model/models/gptoss/model.go, model/models/llama/model.go, model/models/llama4/model.go, model/models/llama4/model_text.go, model/models/mistral3/model.go, model/models/mistral3/model_text.go, model/models/mllama/model.go, model/models/qwen2/model.go, model/models/qwen25vl/model.go, model/models/qwen25vl/model_text.go, model/models/qwen3/model.go, runner/ollamarunner/runner.go]
not_examined: []
