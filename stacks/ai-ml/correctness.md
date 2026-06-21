# Stack pack: ai-ml — correctness
extends: core/skills/correctness/SKILL.md

## Stack-specific signals
- **Data leakage**: test/validation data used in training, preprocessing (fit on the full dataset before split), or feature selection → inflated metrics.
- **Non-determinism**: missing `seed` for `random`/`numpy`/`torch`/`tf` (and `torch.use_deterministic_algorithms` / CUDA determinism) → irreproducible runs.
- **Train/eval skew**: preprocessing/tokenization differs between training and inference; metric computed on wrong split.
- **Silent numerical bugs**: `NaN`/`Inf` in loss/weights not guarded; `argmax`/`softmax` over wrong axis; dtype mismatches (`float32` vs `float16`) causing silent degradation.
- **Batching off-by-one**: dropping the last partial batch, or padding/attention mask mismatch.
- **Eval that always "passes"**: comparing model output with `==` on free-text, or asserting a metric threshold with no tolerance against a noisy metric.
- Stale cached dataset/features used after the data pipeline changed.

## Stack-specific remedies
- Split before fit; set all seeds; assert determinism in CI.
- Reuse one preprocessing path for train and inference; assert finite loss (`torch.isfinite`); validate attention/padding masks.

## Stack-specific severity guidance
- Data leakage invalidating the headline metric: High.
- Non-determinism breaking reproducibility: Medium/High.
- Silent NaN/Inf in a training loop: High.
