# Stack pack: ai-ml — craft
extends: core/skills/craft/SKILL.md

## Stack-specific signals
- A Jupyter notebook as the primary artifact: hidden state, out-of-order cells, unversioned, untestable → not reviewable or reproducible.
- Hardcoded hyperparameters / paths / model names inline in a script or notebook instead of a config (`hydra`, `pydantic-settings`, `argparse`, YAML).
- A god-object `Trainer` / `evaluate(...)` doing data load + model + loop + metrics + save.
- Magic numbers (learning rate, batch size, thresholds, temperature) with no source or name.
- Copy-pasted training/eval loops instead of a shared runner; duplicated data-loading across experiments.
- Eval pipeline that can't be run independently of training.

## Stack-specific remedies
- Move logic out of notebooks into versioned modules; parametrize via config; extract data/loop/metrics/save into focused units.
- Name every magic constant; share one runner for train/eval.

## Stack-specific severity guidance
- Notebook-as-source-of-truth blocking review/reproducibility: High.
- God-object trainer / hardcoded hyperparams hiding the contract: Medium/High.
