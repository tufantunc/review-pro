# Refuting-verifier spike: pre-registration (written 2026-09-24, before any run)

Question: does an independent agent told to refute a finding from source catch findings
known to be false, while leaving findings known to be true standing?

## Label correction made while building the corpus (before any run)

The corpus was planned with the #51 libc claim as a known-false item, because #59
"corrected" it. Rebuilding the item showed #59 was wrong: `cli/package-lock.json` carries
10 `libc` fields at every Linux-generated commit (Dependabot) and 0 at every commit
regenerated on macOS; #53 (0bef451, a local refactor) stripped exactly those 10 as a side
effect, and #59 then measured the stripped file. Re-measured today on macOS, npm 11.9.0,
on the #51 base lockfile: `npm install --package-lock-only` 10 -> 0, `npm version` 10 -> 10.
The claim is TRUE, so the item moved to the true set (V02). The false set was refilled
with the case-3 overcounted sites (V06), verified by reading both tests.
This is itself an instance of the risk under test: a plausible, measured refutation that
killed a true finding.

## Key (the refuters never see this file)

| Item | Label | Source of truth |
|---|---|---|
| V01 | FALSE | CliConfigNames is `internal`; E2E project has no reference to Aspire.Cli; InternalsVisibleTo only to two other projects (pilot case 3) |
| V02 | TRUE  | measured today, see above |
| V03 | TRUE  | fixed upstream, Nerdbank.GitVersioning#1475 |
| V04 | MIXED | core (no multi-page coverage) true; "RoutingHandler returns one canned response" false: it takes a Func<HttpRequestMessage, HttpResponseMessage> (line 906) and tests branch on the request |
| V05 | TRUE  | by construction (step-2 control P5) |
| V06 | FALSE | ConfigDiscoveryTests waits 3 min and accepts `ERR:` as a pass; LocalConfigMigrationTests polls for a file created during discovery, before the build |
| V07 | TRUE  | verified from SDK source at both tags (pilot case 2); the maintainer answer on #1318 did not touch it |
| V08 | FALSE | the loop returns null when `parent is null`, so it is bounded by history depth; the PR's own HEAD~999 test |
| V09 | TRUE  | #71 pass 6, fixed in 518240ad (ADR-0008) |
| V10 | OUT-OF-REPO | code fact true; not a defect per the maintainer (service contract makes created_at non-null). Reported, not scored |
| V11 | TRUE  | three reviewers + hand verification; filed as microsoft/aspire#19540 |
| V12 | TRUE  | by construction (step-2 probe P2) |
| V13 | TRUE  | code correct per case 1; the same defect exists upstream as #718, declined by the maintainer, not disputed |

Sets: FALSE = V01, V06, V08, plus V04's false part. TRUE = V02, V03, V05, V07, V09, V11,
V12, V13, plus V04's core.

## Protocol

Each item runs twice (A, B) with the same prompt (prompt.tmpl), one fresh general-purpose
agent per run, read-only, network allowed for pinned upstream source only, no issues or
PRs. 26 runs. The refuter sees only its FINDING.md and the checkout.

## Coding (per run)

- FALSE item: HIT if verdict is `refuted` and the cited contradiction is the real one
  (or equivalent). MISS otherwise.
- V04: HIT if `partly_refuted`, the falling part is the RoutingHandler claim, and the
  coverage claim stands. `refuted` as a whole is a KILL (it removes a true core).
  `stands` is a MISS.
- TRUE item: OK if `stands`, or `partly_refuted` where the falling part is a real
  inaccuracy and the core stands. KILL if `refuted`, or `partly_refuted` that removes the
  core defect.
- Every run also records: whether the cited contradiction is real (checked by hand),
  whether new findings were added outside `noticed` (scope violation), and wall time.

## Decision rule (fixed before running)

- Proceed to design only if FALSE hits >= 6/8 runs (V01, V06, V08, V04 x2) AND there are
  0 KILLs across all TRUE runs and V04.
- One KILL: this design (verdict + positive-contradiction rule) is not adopted as is; the
  KILL's reasoning decides whether any variant is worth testing.
- Hits < 6/8 with 0 KILLs: the verifier is safe but adds little; not worth a pipeline stage.
- V10 does not enter the rule. Expected good behaviour: `stands` with the service
  contract named under `unchecked`.

## Predictions

- V01 refuted 2/2 (internal class, no reference). V08 refuted 2/2. V06 refuted 1-2/2
  (needs reading test semantics). V04 partly_refuted 1-2/2; the risk is `stands`.
- Expected FALSE hits: 7/8.
- TRUE items stand. Highest KILL risk: V09 (a text-level finding; a refuter may argue the
  rubric's line 19 or "option injection still applies" covers it) and V02 (a refuter
  cannot run npm and may assert npm behaviour from memory). Lower risk: V12 (flag
  off by default read as a refutation).
- Expected KILLs: 0, with V09 or V02 the likeliest single exception.
- Scope violations (new findings outside `noticed`): 0-2 of 26.
