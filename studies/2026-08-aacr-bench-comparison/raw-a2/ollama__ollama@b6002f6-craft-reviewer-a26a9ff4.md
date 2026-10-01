<!-- ollama__ollama@b6002f6 craft-reviewer; verbatim final answer -->
I found three craft problems in this change, all Medium or Low, and no blocking structural regression. Moving positions and outputs onto `input.Batch` as tensors removes about 14 duplicated `FromIntSlice` lines from the model packages, and that part is good. The cost lands in `kvcache`, which reads positions on the CPU and now has to decode them back out of the tensor.

- severity: Medium
  category: craft.boundary
  file: model/input/input.go
  line: 59
  title: Host-side positions are uploaded to a tensor, then decoded back by every CPU consumer
  evidence: |
    // model/input/input.go
    -	Positions []int32
    +	Positions ml.Tensor

    // runner/ollamarunner/runner.go:582
    +	batch.Positions = nextBatch.ctx.Input().FromIntSlice(batchPositions, len(batchPositions))

    // kvcache/causal.go:203
    +	c.curPositions = batch.Positions.Ints()
    // kvcache/encoder.go:94
    +		c.curPos = batch.Positions.Ints()[batch.Multimodal[len(batch.Multimodal)-1].Index]
    // kvcache/wrapper.go:50
    +				curPositions := batch.Positions.Ints()
    // model/models/llama4/model_text.go:222
    +		for i, p := range batch.Positions.Ints() {
  impact: |
    Positions are CPU data: the cache uses them for cell bookkeeping, masks and removal. The runner already builds `batchPositions []int32`, turns it into a tensor, and four consumers turn it back with the new `Tensor.Ints()`. The old `[]int32` type guaranteed these values were readable on the CPU. Now that guarantee sits in `ggml_get_data(t.t) != nil` inside the ggml backend (ggml.go:1035). If the tensor is not on the CPU, `Ints()` quietly returns nil and `kvcache` has no way to see it. This is also why `Ints()` had to be added to `ml.Tensor` (ml/backend.go:404) and implemented in both the ggml backend and `testTensor`. Every test now wraps plain slices in `context.FromIntSlice(...)` just to hand the cache data it only reads back.
  remedy: |
    Keep the host slice as the source of truth. `Sequences` already works this way and stays `[]int`. Two options:
    - Keep `Positions []int32` for CPU consumers and add a model-facing `PositionsTensor ml.Tensor` that the runner builds once, next to the existing `batch.Inputs = ...Empty(...)` line.
    - Keep `Positions ml.Tensor` and pass the host `[]int32` to `Cache.StartForward` separately.
    Either way, models still get the tensor for free, `kvcache` stops depending on backend memory placement, `Ints()` can be dropped from `ml.Tensor`, and `causal_test.go` goes back to plain slices.
  evidence_refs: [runner/ollamarunner/runner.go:582, kvcache/causal.go:203, kvcache/encoder.go:94, kvcache/wrapper.go:50, model/models/llama4/model_text.go:222, ml/backend.go:404, ml/backend/ggml/ggml.go:1035, kvcache/causal_test.go:395]
  confidence: medium
  overlap_hints: [api-contract.type-boundary, correctness.logic]

- severity: Medium
  category: craft.abstraction
  file: ml/backend/ggml/ggml.go
  line: 1029
  title: Bytes/Floats/Ints are copied three times and disagree on whether they return a copy or an alias
  evidence: |
    func (t *Tensor) Ints() (data []int32) {
    	if t.sync != nil {
    		data = make([]int32, C.ggml_nelements(t.t))
    		t.sync()
    		C.ggml_backend_tensor_get(t.t, unsafe.Pointer(&data[0]), 0, C.ggml_nbytes(t.t))
    	} else if bts := C.ggml_get_data(t.t); bts != nil {
    		// tensor is in cpu memory
    		data = unsafe.Slice((*int32)(bts), C.ggml_nelements(t.t))
    	}
    	return
    }
    // Floats() (1015-1027): same shape, also returns unsafe.Slice alias on the new branch
    // Bytes() (1001-1013): same shape, but returns a C.GoBytes COPY on the new branch
  impact: |
    The same sync-or-CPU-pointer logic now appears three times.
    - `Bytes()` returns a Go-owned copy on the CPU branch; `Floats()` and `Ints()` return a view into ggml memory that dies with the context. So whether a result is safe to keep or mutate depends on which method you call and where the tensor happens to live. None of this is documented on the `ml.Tensor` interface.
    - `Floats()` used to always return a Go-owned slice or nil. This change quietly turns it into an alias for CPU tensors.
    - A fourth accessor would repeat the same code again.
  remedy: |
    Replace the three bodies with one generic helper, for example `func tensorData[T any](t *Tensor) []T`, that picks one ownership rule. Always copying on the CPU branch (like `Bytes`) is simplest. Then make `Bytes`, `Floats` and `Ints` one-line calls to it. If aliasing is truly needed for speed, name it in the API (for example `IntsView`) instead of changing `Floats()` underneath its existing callers.
  confidence: high
  overlap_hints: [dry.duplication, correctness.logic, api-contract.type-boundary]

- severity: Low
  category: craft.spaghetti
  file: model/models/mllama/model.go
  line: 110
  title: mllama keeps the old exploded TextModel.Forward signature while its siblings switched to taking the batch
  evidence: |
    // mllama/model.go:110
    return m.TextModel.Forward(ctx, batch.Inputs, batch.Positions, batch.Outputs, crossAttentionStates, nil, m.Cache.(*kvcache.WrapperCache)), nil
    // mllama/model_text.go:218 (unchanged)
    func (m *TextModel) Forward(ctx ml.Context, inputIDs, positionIDs, outputs, crossAttentionStates, crossAttentionMask ml.Tensor, cache *kvcache.WrapperCache) ml.Tensor {
    // vs. llama4/mistral3/qwen25vl/gemma3/gemma3n after this PR:
    func (m *TextModel) Forward(ctx ml.Context, batch input.Batch, cache kvcache.Cache) ml.Tensor {
  impact: |
    The commit's stated goal is to clean up the model interface. mllama is now the only multimodal model whose text model still takes batch fields as loose arguments. The next person adding a field to `input.Batch` has two conventions to follow.
  remedy: |
    Change `mllama.TextModel.Forward` to take `(ctx, batch input.Batch, crossAttentionStates ml.Tensor, cache *kvcache.WrapperCache)`. Read `batch.Inputs`, `batch.Positions` and `batch.Outputs` inside it, and drop `crossAttentionMask`, which is always nil (TODO at model.go:109).
  evidence_refs: [model/models/mllama/model_text.go:218, model/models/llama4/model_text.go:211]
  confidence: high
  overlap_hints: []

Not raised: `ggml.go` (1611 lines) and `runner.go` (1308 lines) were already over 1000 lines before this change and grow only slightly, so the 1k-line rule does not apply. Using `Arange(..., ml.DTypeI32)` for `Outputs` in `reserveWorstCaseGraph` correctly reuses the existing helper.

## Files examined
examined: [kvcache/causal.go, kvcache/causal_test.go, kvcache/encoder.go, kvcache/wrapper.go, ml/backend.go, ml/backend/ggml/ggml.go, model/input/input.go, model/model.go, model/models/gemma2/model.go, model/models/gemma3/model_text.go, model/models/gemma3n/model_text.go, model/models/gptoss/model.go, model/models/llama/model.go, model/models/llama4/model.go, model/models/llama4/model_text.go, model/models/mistral3/model.go, model/models/mistral3/model_text.go, model/models/mllama/model.go, model/models/qwen2/model.go, model/models/qwen25vl/model.go, model/models/qwen25vl/model_text.go, model/models/qwen3/model.go, runner/ollamarunner/runner.go]
not_examined: []
