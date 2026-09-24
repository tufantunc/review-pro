# Study: does a refuting verifier catch false findings without killing true ones?

A pre-registered spike, run 2026-09-24, before any design work on a verification stage
for review-pro. It is step 3 of the ideas borrowed from
[cloudflare/security-audit-skill](https://github.com/cloudflare/security-audit-skill).

**Headline:** the refuter caught 6 of 8 runs on known-false findings, which met the
pre-registered threshold exactly. It added no new findings in 26 runs. Both runs
refuted one finding the corpus labelled true, and that label turned out to be wrong: the
pilot's case-3 finding, filed upstream as microsoft/aspire#19540, does not hold. On the
corrected labels, no true finding was refuted.

## Contents

| File | What it is |
|---|---|
| [`PRE-REGISTRATION.md`](PRE-REGISTRATION.md) | Question, answer key, coding, decision rule and predictions, written before any run |
| [`prompt.tmpl`](prompt.tmpl) | The refuter prompt every run received, with only the item path filled in |
| [`items/`](items) | The 13 findings as the refuters saw them; the key lives only in the pre-registration |
| [`raw/`](raw) | Every run's final answer, verbatim, `<item>-<run>.md` |
| [`RESULTS.md`](RESULTS.md) | Coded results, the rule outcome, and the adjudication of the one refuted true-labelled item |
| [`SHA256SUMS`](SHA256SUMS) | Hashes of the prompt, pre-registration and item files, taken before the first run |

## Timeline, honestly

Everything ran in one session. `SHA256SUMS` was written at 06:01:06Z, before the first
run, and the files here still match it. The directory itself was committed after the
runs, so git timestamps prove nothing about ordering, and we do not claim they do.

Two things happened after a run had been seen, and both are marked where they happen:

- The case-3 item (V11) was re-adjudicated after both runs refuted it. The rule as
  pre-registered says "not adopted as is". `RESULTS.md` gives that outcome first, then
  the source lines that make the label wrong, then the caveat that the maintainer judged
  his own instrument.
- The pre-registration attributes the libc effect to "macOS, npm 11.9.0". Run V02-A
  correctly separated the two. Later measurement on one machine showed that the npm
  version is the cause: npm 11.10.0 strips the fields, 11.11.0 keeps them. The
  pre-registration is left as hashed.

## What the corpus is

Findings from earlier review-pro work whose truth was known, rebuilt at the commit they
were written against. Upstream repositories were fetched at the PR head and nothing
later. Base and head:

| Checkout | Repository | Head | Base |
|---|---|---|---|
| nbgv | dotnet/Nerdbank.GitVersioning#1438 | `a31b5c33` | `a147f03e` |
| extensions | dotnet/extensions#7608 | `868c7104` | `7e8c785a` |
| aspire | microsoft/aspire#18671 | `8eeb25bd` | `5552e243` |
| rp51 | review-pro#51, as it stood under review (see below) | synthetic | `12e00238` |
| rp71 | review-pro#71 at pass 6 | `3567891a` | its merge base with main |
| probe-p2, probe-p5 | the step-2 probe service, two branches | local | local |

rp51 is reconstructed. At #51's head the validator already printed the `npm version`
remedy and the comment explained the libc effect, which would have handed the refuter
the answer. The item restores the state under review: the error message prints
`npm install --package-lock-only` and the rationale paragraph is removed. The commit
was rewritten onto the base so the later text is unreachable.

Most finding texts are reconstructed from the pilot case files in the shared schema,
not copied from raw reviewer output, which was not kept. V09 is the pass-6 reviewer's
block verbatim.

## What it changed

- review-pro#72 restored the libc rationale that #59 had retracted in error.
- review-pro#73 added dated corrections to the pilot's case-3 record and upstream
  disclosure.
- A correction was posted on microsoft/aspire#19540, and the issue was retitled to the
  part that stands.
- The design at `docs/superpowers/specs/2026-09-24-refuting-verifier-design.md` is
  built on this evidence, including its limits.

## Conflict of interest

The study's author maintains review-pro, and one model family played reviewer, refuter
and adjudicator. The hash file, the verbatim outputs, and the two places where a label
changed after the fact are here so that someone else can disagree with the reading.
