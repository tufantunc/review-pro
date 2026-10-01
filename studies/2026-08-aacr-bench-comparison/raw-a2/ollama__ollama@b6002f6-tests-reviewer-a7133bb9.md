<!-- ollama__ollama@b6002f6 tests-reviewer; verbatim final answer -->
## Tests findings

- severity: High
  category: tests.coverage
  file: ml/backend/ggml/ggml.go
  line: 1029
  title: The new ggml Tensor.Ints() and the CPU-memory fallback in Bytes()/Floats() have no tests
  evidence: |
    func (t *Tensor) Ints() (data []int32) {
    	if t.sync != nil {
    		data = make([]int32, C.ggml_nelements(t.t))
    		...
    	} else if bts := C.ggml_get_data(t.t); bts != nil {
    		// tensor is in cpu memory
    		data = unsafe.Slice((*int32)(bts), C.ggml_nelements(t.t))
    	}
    	return
    }
    // and in Bytes()/Floats():
    } else if bts := C.ggml_get_data(t.t); bts != nil {
  evidence_refs: [kvcache/causal.go:203, kvcache/causal.go:204, kvcache/encoder.go:94, kvcache/wrapper.go:50, model/models/llama4/model_text.go:222, ml/backend/ggml/ggml.go:931]
  impact: |
    Every forward pass now reads positions through this path before compute. `Causal.StartForward` gets both the positions and `curBatchSize` from `batch.Positions.Ints()`. `ml/backend/ggml` has no `_test.go` file, and no test anywhere constructs a real ggml tensor and calls `Ints()`, `Bytes()` or `Floats()` on it.
    The following cases can all regress without any test failing:
    - The `sync == nil` / `ggml_get_data` branch.
    - The `ggml_get_data == nil` branch, which returns nil. In `Causal` that makes `curBatchSize` 0.
    - The fact that the fallback returns an alias of tensor memory rather than a copy.
    - Tensors built when `allocMemory` is false, where `FromIntSlice` skips `ggml_backend_tensor_set` and the buffer is never initialised.
  remedy: |
    Add `ml/backend/ggml/ggml_test.go`. Write a tiny GGUF with `fs/ggml.WriteGGUF` (the pattern already used at `llm/memory_test.go:37`) and open a CPU backend with `ggml.New`. Then assert on:
    - (a) `ctx.Input().FromIntSlice([]int32{3,1,4}, 3).Ints()` equals `{3,1,4}`.
    - (b) `FromFloatSlice(...).Floats()` and `.Bytes()` round-trip, including the byte length (`nbytes`).
    - (c) A zero-length `FromIntSlice(nil, 0)` returns an empty or nil slice without panicking.
    - (d) The post-`Compute` (`sync != nil`) path returns computed values.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Medium
  category: tests.test-data
  file: kvcache/causal_test.go
  line: 675
  title: The test double's Ints() ignores dtype and always copies, so it hides the ggml aliasing and dtype behaviour
  evidence: |
    func (t *testTensor) Ints() []int32 {
    	out := make([]int32, len(t.data))
    	for i := range out {
    		out[i] = int32(t.data[i])
    	}
    	return out
    }
  evidence_refs: [ml/backend/ggml/ggml.go:1037, kvcache/causal.go:203]
  impact: |
    The fake differs from ggml in three ways:
    - It converts float32 values to int32 for any dtype. ggml reinterprets the raw bits as int32. A Positions tensor accidentally built as F32 would pass every kvcache test and produce garbage positions in production.
    - It always returns a fresh copy. For CPU tensors, ggml returns `unsafe.Slice` over the tensor's own memory. `Causal` stores that slice in `c.curPositions` for the whole forward, so a test can never catch a bug where the slice is mutated or outlives the tensor.
    - It never returns nil. ggml returns nil when `ggml_get_data` is nil, so the `curBatchSize == 0` case is unreachable in tests.
  remedy: |
    - Make `testTensor.Ints()` panic (or `t.Fatal`) when `t.dtype != ml.DTypeI32`, matching the int32 contract the callers rely on.
    - Add a `Causal` test where `Positions` is an empty `FromIntSlice(nil, 0)` batch, and assert the resulting error or behaviour.
    - Cover the aliasing semantics in the ggml-level test from the finding above.
  confidence: medium
  overlap_hints: [correctness.logic]

- severity: Medium
  category: tests.coverage
  file: runner/ollamarunner/runner.go
  line: 582
  title: Runner batch-tensor construction and the Outputs.Dim(0)-based vocabSize are untested
  evidence: |
    batch.Positions = nextBatch.ctx.Input().FromIntSlice(batchPositions, len(batchPositions))
    batch.Outputs = nextBatch.ctx.Input().FromIntSlice(batchOutputs, len(batchOutputs))
    ...
    vocabSize := len(outputs) / activeBatch.batch.Outputs.Dim(0)
    ...
    batch.Outputs = ctx.Input().Arange(0, float32(s.parallel), 1, ml.DTypeI32)
  evidence_refs: [runner/ollamarunner/runner.go:711, runner/ollamarunner/runner.go:1070, runner/ollamarunner/cache_test.go:446]
  impact: |
    Three behaviours are unverified:
    - `forwardBatch` now collects positions and outputs in local slices. The `seq.iBatch = len(batchOutputs)` indexing and the tensors built from those slices have no test.
    - `computeBatch` now slices logits by `Outputs.Dim(0)`.
    - `reserveWorstCaseGraph` switched from a manual loop to `Arange(..., DTypeI32)` for Outputs, and moved the `Sequences` allocation.

    The only runner test file (`cache_test.go`) uses a `mockCache` whose `StartForward` returns nil and never builds a batch. A mismatch between `iBatch` and the Outputs order, or a wrong `vocabSize` split, would sample from the wrong logits row and no test would fail.
  remedy: |
    Extract the batch-assembly step (inputs → Positions/Outputs/Sequences plus each seq's `iBatch`) into a helper that takes an `ml.Context`. Test it with the `testContext` from `kvcache/causal_test.go`, or an equivalent fake, and assert all of the following for two sequences of different lengths:
    - `Positions.Ints()`
    - `Outputs.Ints()`
    - each sequence's `iBatch`
  confidence: medium
  overlap_hints: [correctness.logic]

- severity: Medium
  category: tests.coverage
  file: kvcache/encoder.go
  line: 94
  title: EncoderCache and the WrapperCache unwind path now read Positions.Ints() and have no test
  evidence: |
    c.curPos = batch.Positions.Ints()[batch.Multimodal[len(batch.Multimodal)-1].Index]
    // wrapper.go
    curPositions := batch.Positions.Ints()
    for k := range curPositions {
    	_ = c.caches[j].Remove(batch.Sequences[k], curPositions[k], math.MaxInt32)
  evidence_refs: [kvcache/wrapper.go:50]
  impact: |
    `kvcache/` has only `causal_test.go`, and it never sets `Multimodal` or uses `WrapperCache`/`EncoderCache`. The multimodal position lookup, which is mllama's cross-attention position, and the rollback that runs when a later wrapped cache fails `StartForward` both changed in this diff. Neither is exercised.
  remedy: |
    Using the existing `testBackend`/`testContext`:
    - Add an `EncoderCache` test that calls `StartForward` with `Positions: ctx.FromIntSlice([]int32{0,1,2}, 3)` and `Multimodal: []input.MultimodalIndex{{Index: 2}}`, then asserts `curPos == 2`.
    - Add a `WrapperCache` test where the second cache is full, so its `StartForward` fails, and assert that the first cache's cells for those positions were removed.
  confidence: high
  overlap_hints: []

- severity: Low
  category: tests.coverage
  file: model/model.go
  line: 285
  title: The rewritten Forward length/empty-batch validation has no test
  evidence: |
    if batch.Positions.Dim(0) != len(batch.Sequences) {
    	return nil, fmt.Errorf("length of positions (%v) must match length of seqs (%v)", batch.Positions.Dim(0), len(batch.Sequences))
    }
    if batch.Positions.Dim(0) < 1 {
  evidence_refs: [model/model_test.go:176]
  impact: |
    The guard now depends on `Dim(0)` of a tensor instead of `len` of a slice. A zero-length tensor from `newTensor`, which is created with `ne=0`, should still hit "batch size cannot be less than 1". A nil `Positions` now panics where it used to return an error. `model_test.go` never calls `model.Forward`, so neither case is checked.
  remedy: |
    Add table cases to `model/model_test.go` that call `model.Forward` with a stub model and fake tensors:
    - Positions dim 3 with 2 sequences, expecting the mismatch error.
    - Positions dim 0, expecting the batch-size error.
  confidence: medium
  overlap_hints: [correctness.logic]

## Files examined
examined: [kvcache/causal.go, kvcache/causal_test.go, kvcache/encoder.go, kvcache/wrapper.go, ml/backend.go, ml/backend/ggml/ggml.go, model/input/input.go, model/model.go, model/models/gemma2/model.go, model/models/gemma3/model_text.go, model/models/gemma3n/model_text.go, model/models/gptoss/model.go, model/models/llama/model.go, model/models/llama4/model.go, model/models/llama4/model_text.go, model/models/mistral3/model.go, model/models/mistral3/model_text.go, model/models/mllama/model.go, model/models/qwen2/model.go, model/models/qwen25vl/model.go, model/models/qwen25vl/model_text.go, model/models/qwen3/model.go, runner/ollamarunner/runner.go]
not_examined: []
