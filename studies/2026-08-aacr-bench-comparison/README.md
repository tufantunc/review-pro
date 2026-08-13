# Study: standard harness review vs. review-pro on AACR-Bench

**Status: pre-registered, not yet run.** This directory currently contains only the
locked design. Results, instance lists, raw outputs, and the write-up land here as
the study proceeds.

## The question

The [pilot study](../2026-08-copilot-pr-pilot) found that the defects in merged
agent-authored PRs live in the repository, not in the diff — existing guards,
canonical helpers, upstream sources. That produced a claim about *architecture*:
review that leaves the diff finds things a diff-scoped review cannot.

This study tests that claim against external ground truth.

[AACR-Bench](https://github.com/alibaba/aacr-bench) (Alibaba, Apache-2.0) is a
repository-level code review benchmark: 200 real PRs, 50 projects, 10 languages,
2,145 expert-verified reference comments. Crucially for us, **every reference
comment carries a context label — diff / file / repo.** That turns the
architectural claim into a measurable one:

> At the same harness and the same model, does review-pro find more of the
> **repo-context** reference comments than the harness's own standard review
> command — without paying for it in noise?

## Design in one paragraph

Paired, within-model. Each benchmark instance is reviewed twice at the same
harness and model: once by the framework's built-in reviewer running the official
`/code-review` slash command (unmodified — we did not define our opponent), once
by review-pro through an adapter that reports into the same finding contract. The
readout is the **within-instance paired delta**, which is also the defense against
training-data contamination: these are public PRs, contamination inflates both
arms of the same model, and the delta survives it. One non-Anthropic judge
(GLM-5.2) scores every arm, three rounds, averaged.

Full design, endpoints, anti-gaming rules, and limitations:
**[PRE-REGISTRATION.md](PRE-REGISTRATION.md)**.

## What would falsify the thesis

If repo-context recall does not improve, or improves only by exceeding the noise
budget, the article's architectural claim is weakened — and that is what gets
published. Same posture as the pilot, which reported a negative result on its own
headline premise and two author-side false positives.

## Where the pieces live

| | |
|---|---|
| Locked design, results, write-up | this directory |
| Framework fork + the review-pro adapter | [`tufantunc/aacr-bench`](https://github.com/tufantunc/aacr-bench) (public, pinned by commit in the registration) |
| Benchmark + dataset | [`alibaba/aacr-bench`](https://github.com/alibaba/aacr-bench), Apache-2.0 |

## Conflict of interest

The author maintains review-pro. The mitigations are structural rather than
promised: external expert-verified ground truth (we label nothing ourselves), the
opposing arm is the framework's own unmodified reviewer, a judge from a different
model family than any arm, a design committed before the adapter exists, and
instance-level raw outputs published for independent re-scoring.

## Citation

```bibtex
@misc{zhang2026aacrbenchevaluatingautomaticcode,
      title={AACR-Bench: Evaluating Automatic Code Review with Holistic Repository-Level Context},
      author={Lei Zhang and Yongda Yu and Minghui Yu and Xinxin Guo and Zhengqi Zhuang and Guoping Rong and Dong Shao and Haifeng Shen and Hongyu Kuang and Zhengfeng Li and Boge Wang and Guoan Zhang and Bangyu Xiang and Xiaobin Xu},
      year={2026},
      eprint={2601.19494},
      archivePrefix={arXiv},
      primaryClass={cs.SE},
      url={https://arxiv.org/abs/2601.19494},
}
```
