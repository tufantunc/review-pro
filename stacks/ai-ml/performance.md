# Stack pack: ai-ml — performance
extends: core/skills/performance/SKILL.md

## Stack-specific signals
- Unbatched inference (one call per item) instead of batching; or attention/matmul with O(n²) on long sequences where chunking/flash-attention applies.
- `pandas.DataFrame.iterrows()` / Python loops over tensors instead of vectorized numpy/torch ops.
- Re-running the same model/preprocessing per request instead of caching (embeddings, tokenizer, compiled graph).
- Unnecessary GPU↔CPU syncs (`.item()`, `.cpu()`, printing tensors) inside hot loops.
- Recomputing frozen-embedding / tokenizer / constant data per call rather than once.
- Loading the model inside the request handler instead of at startup.

## Stack-specific remedies
- Batch inference; vectorize; cache embeddings/compiled graphs; move `.item()`/`.cpu()` out of hot loops; load the model once at startup.

## Stack-specific severity guidance
- Unbatched inference or O(n²) attention on a serving path: High.
- Per-request model load: High.
- GPU-sync churn in a hot loop: Medium/High.
