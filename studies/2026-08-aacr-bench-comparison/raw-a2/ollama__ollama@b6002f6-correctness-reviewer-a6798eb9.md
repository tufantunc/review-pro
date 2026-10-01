<!-- ollama__ollama@b6002f6 correctness-reviewer; verbatim final answer -->
- severity: High
  category: correctness.side-effect
  file: ml/backend/ggml/ggml.go
  line: 1035
  title: Ints() reads a fake pointer during the memory-fit pass, so every llama4 load and every mllama load with a vision model fails
  evidence: |
    } else if bts := C.ggml_get_data(t.t); bts != nil {
        // tensor is in cpu memory
        data = unsafe.Slice((*int32)(bts), C.ggml_nelements(t.t))
    }
  evidence_refs:
    - runner/ollamarunner/runner.go:1204   (AllocMemory: req.Operation != llm.LoadOperationFit)
    - llm/server.go:709                    (every load starts with LoadOperationFit)
    - ml/backend/ggml/ggml.go:931          (FromIntSlice copies no data when !allocMemory)
    - ml/backend/ggml/ggml/src/ggml-backend.cpp:135-136  (no_alloc buffer base = (void *)alignment, i.e. 0x20)
    - ml/backend/ggml/ggml/src/ggml.c:1777 (ggml_get_data returns tensor->data unchanged)
    - model/models/llama4/model_text.go:204,220-223  (attentionTemperatureTuning defaults to true; loop over batch.Positions.Ints())
    - kvcache/encoder.go:94                (batch.Positions.Ints()[idx] when batch.Multimodal is non-empty)
    - runner/ollamarunner/runner.go:1020-1080  (reserveWorstCaseGraph adds a multimodal input, then calls StartForward and Forward)
    - runner/ollamarunner/runner.go:1102-1108,1226  (recover turns the panic into "failed to initialize model")
  impact: |
    Every ollamarunner load first runs a Fit pass with AllocMemory=false. In that pass, reserveWorstCaseGraph builds Positions with ctx.Input().FromIntSlice, which writes no data. The CPU input buffer is a no_alloc buffer, so the tensor's data pointer is the placeholder (void*)32. It is not NULL, so the new fallback wraps it in a Go slice. Two places then read values from it:
    (1) llama4 TextModel.Forward. `attention.temperature_tuning` defaults to true, and no in-repo code writes that key, so this runs for every llama4 model.
    (2) EncoderCache.StartForward, which mllama reaches through WrapperCache when the vision encoder is present, because the worst-case graph includes an image.
    Reading address 0x20 raises a Go nil-dereference panic. allocModel recovers it as an error, and the load request returns HTTP 500 "failed to initialize model: runtime error: invalid memory address...". Neither model family can be loaded. Before this change, positions were a Go []int32, so this path never touched tensor memory. Causal.StartForward is safe here because it only takes len() when reserve is true.
  remedy: |
    Do not read tensor data when the backend is not allocating memory. For example, return nil or zeros from Ints/Floats/Bytes when !t.b.allocMemory or when the buffer is no_alloc, and have callers accept that (llama4 can skip the scale values when reserving). Alternatively, keep the host-side []int32 positions on input.Batch next to the tensor and use that for Go-side logic in llama4 and EncoderCache. Add a test that runs reserveWorstCaseGraph with AllocMemory=false for a model that reads positions.
  confidence: high
  overlap_hints: [api-contract.breaking, tests.coverage]

- severity: Low
  category: correctness.logic
  file: ml/backend/ggml/ggml.go
  line: 1007
  title: Bytes()/Floats() fallback assumes host memory and dereferences device pointers, which breaks ml.Dump's "not computed" check
  evidence: |
    } else if bts := C.ggml_get_data(t.t); bts != nil {
        // tensor is in cpu memory
        data = C.GoBytes(bts, C.int(C.ggml_nbytes(t.t)))
  evidence_refs:
    - ml/backend.go:567-569   (if t.Bytes() == nil { ctx.Forward(t).Compute(t) })
    - ml/backend/ggml/ggml/src/ggml.c:1777
  impact: |
    ggml_get_data returns tensor->data whatever buffer backs the tensor, so the "cpu memory" comment is not enforced. Two cases break:
    - A GPU-resident tensor with sync == nil, such as a CUDA/ROCm weight or a graph intermediate left out of Compute's list, now makes GoBytes or unsafe.Slice read a device address from the host and segfault.
    - ml.Dump used a nil Bytes() to mean "compute this first". It now gets bytes back (or crashes) without computing, and can print stale or uninitialized data.
    Impact is limited because Dump has no in-repo callers (it is a debug helper). The current Ints() callers read only CPU input tensors.
  remedy: Take the fallback only when C.ggml_backend_buffer_is_host(t.t.buffer) is true (and the buffer is not no_alloc). Otherwise keep returning nil so Dump still computes first.
  confidence: medium
  overlap_hints: [api-contract.behavior-change]

## Files examined
examined: [kvcache/causal.go, kvcache/causal_test.go, kvcache/encoder.go, kvcache/wrapper.go, ml/backend.go, ml/backend/ggml/ggml.go, model/input/input.go, model/model.go, model/models/gemma2/model.go, model/models/gemma3/model_text.go, model/models/gemma3n/model_text.go, model/models/gptoss/model.go, model/models/llama/model.go, model/models/llama4/model.go, model/models/llama4/model_text.go, model/models/mistral3/model.go, model/models/mistral3/model_text.go, model/models/mllama/model.go, model/models/qwen2/model.go, model/models/qwen25vl/model.go, model/models/qwen25vl/model_text.go, model/models/qwen3/model.go, runner/ollamarunner/runner.go]
not_examined: []
