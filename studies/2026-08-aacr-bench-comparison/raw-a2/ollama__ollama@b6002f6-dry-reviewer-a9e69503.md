<!-- ollama__ollama@b6002f6 dry-reviewer; verbatim final answer -->
## DRY findings

- severity: Medium
  category: dry.copy-paste
  file: ml/backend/ggml/ggml.go
  line: 1029
  title: New Tensor.Ints() is a copy of Tensor.Floats() (ggml.go:1015) with only the element type changed
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
  evidence_refs: [ml/backend/ggml/ggml.go:1015, ml/backend/ggml/ggml.go:1001]
  impact: Floats() (1015-1026) and Ints() (1029-1040) are the same code apart from `float32` vs `int32`. This commit also added the same new `else if ggml_get_data` CPU-memory branch to Bytes(), Floats() and Ints() (lines 1007, 1021, 1035). So there are now three copies of the sync / backend-get / CPU-fallback logic. Any later fix has to be made three times and could be missed in one of them. Examples: the empty-tensor `&data[0]` panic when nelements==0, or the aliasing difference where the CPU path returns a view into tensor memory while the sync path returns a copy. Each new dtype accessor adds another copy.
  remedy: Go 1.24 (go.mod) supports generics. Pull the shared body into one package-level generic function, e.g. `func tensorData[T any](t *Tensor) (data []T) { if t.sync != nil { data = make([]T, C.ggml_nelements(t.t)); t.sync(); C.ggml_backend_tensor_get(t.t, unsafe.Pointer(&data[0]), 0, C.ggml_nbytes(t.t)) } else if p := C.ggml_get_data(t.t); p != nil { data = unsafe.Slice((*T)(p), C.ggml_nelements(t.t)) }; return }`. Then make `Floats()` return `tensorData[float32](t)` and `Ints()` return `tensorData[int32](t)`. Bytes() can use `tensorData[byte]` too, or keep its GoBytes copy if the copy semantics matter. That way the element-count/byte-count and the CPU-path decision live in one place.
  confidence: high
  overlap_hints: [craft.code-judo, correctness]

- severity: Low
  category: dry.missing-abstraction
  file: kvcache/wrapper.go
  line: 50
  title: The positions slice is derived again with batch.Positions.Ints() at four separate call sites, even though the runner already built it
  evidence: |
    for j := i - 1; j >= 0; j-- {
    	curPositions := batch.Positions.Ints()
    	for k := range curPositions {
    		_ = c.caches[j].Remove(batch.Sequences[k], curPositions[k], math.MaxInt32)
  evidence_refs: [kvcache/causal.go:203, kvcache/encoder.go:94, model/models/llama4/model_text.go:222, runner/ollamarunner/runner.go:552, runner/ollamarunner/runner.go:582]
  impact: The runner builds `batchPositions []int32` (runner.go:552), wraps it in a tensor (runner.go:582) and drops the slice. Each consumer then reads it back out: causal.go:203, encoder.go:94, wrapper.go:50 and llama4/model_text.go:222 each call `batch.Positions.Ints()` again, and wrapper.go calls it once per iteration of the outer unwind loop. The same host-side data now comes from several places. When the tensor is not CPU-resident, each call does another backend sync and copy.
  remedy: Derive the host-side positions once. One way is to hoist `batch.Positions.Ints()` out of the `j` loop in wrapper.go and reuse `c.curPositions` wherever the causal cache already holds it. A cleaner way is to keep the `[]int32` the runner already built alongside the tensor, so the kvcache and llama4 consumers read one canonical slice instead of four readbacks.
  confidence: medium
  overlap_hints: [performance, craft.abstraction]

I checked two other things and am not reporting them:
- `testTensor.Ints` vs `testTensor.Floats` (kvcache/causal_test.go:669/675): the bodies differ in substance (a plain `copy` vs a per-element float-to-int32 conversion), so there's nothing to share.
- The FromIntSlice calls removed from each model's `Forward`: the diff takes that repeated conversion out of 13 model files and puts it in one place in the runner, which reduces duplication.

## Files examined
examined: [kvcache/causal.go, kvcache/causal_test.go, kvcache/encoder.go, kvcache/wrapper.go, ml/backend.go, ml/backend/ggml/ggml.go, model/input/input.go, model/model.go, model/models/gemma2/model.go, model/models/gemma3/model_text.go, model/models/gemma3n/model_text.go, model/models/gptoss/model.go, model/models/llama/model.go, model/models/llama4/model.go, model/models/llama4/model_text.go, model/models/mistral3/model.go, model/models/mistral3/model_text.go, model/models/mllama/model.go, model/models/qwen2/model.go, model/models/qwen25vl/model.go, model/models/qwen25vl/model_text.go, model/models/qwen3/model.go, runner/ollamarunner/runner.go]
not_examined: []
