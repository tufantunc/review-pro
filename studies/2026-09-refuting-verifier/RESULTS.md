# Refuting-verifier spike: results (2026-09-24)

26 runs, 13 items x 2, general-purpose agents, prompt.tmpl unchanged from the hashed
version. Per run: 22-134 s, 61-93k subagent tokens (about 1.9M in total).

| Item | Label | A | B | Coded (pre-registered) |
|---|---|---|---|---|
| V01 | FALSE | partly_refuted (remedy falls: CliConfigNames internal, no reference; duplication "stands") | same | MISS, MISS |
| V04 | MIXED | partly_refuted (RoutingHandler claim falls, coverage stands) | same | HIT, HIT |
| V06 | FALSE | refuted (ERR: accepted, file poll) | refuted, same reason | HIT, HIT |
| V08 | FALSE | refuted (returns at root commit) | refuted, same reason | HIT, HIT |
| V02 | TRUE  | partly_refuted: "specific to macOS" falls, npm < 11.11 drops libc on any OS; core stands | stands | OK, OK |
| V03 | TRUE  | stands (notes throw site is :616, not :334) | partly_refuted, only the line number falls | OK, OK |
| V05 | TRUE  | stands | stands | OK, OK |
| V07 | TRUE  | stands | stands | OK, OK |
| V09 | TRUE  | stands | stands | OK, OK |
| V11 | TRUE  | refuted | partly_refuted, only the doc-comment inaccuracy stands | KILL, KILL |
| V12 | TRUE  | stands | stands | OK, OK |
| V13 | TRUE  | stands | stands | OK, OK |
| V10 | OUT   | stands, service contract under unchecked | same | good, good |

FALSE hits: 6/8 (threshold 6/8 met exactly). KILLs by label: 2 (both V11).
Scope violations: 0/26; every extra observation went to `noticed`.

## Rule outcome as pre-registered

One or more KILL: the design is not adopted as is, and the KILL's reasoning decides
whether a variant is worth testing.

## The KILL's reasoning, checked by hand

Both V11 runs, independently, cite the same mechanism, and it checks out at 8eeb25bd:
- Aspire.Hosting.AppHost.in.targets:318: under the CLI run hook, `dotnet run` builds, then
  runs `aspire run --project ... --no-build --`.
- RunCommand.cs:277-278: `NoBuild = noBuild, NoRestore = noBuild`; the 120 s timer
  (:296) never covers the cold restore and build.
- The only limit covering restore + build + startup at BundleSmokeTests :97/:157 was the
  2 minute terminal wait; the PR raises it to 240 s. The flake is mitigated there.
- The CLI's own timeout still fires (after the build) and prints RunCommandStrings:233,
  so "no compensating diagnostic" is false.
What stands: the AspireRunReadyTimeout doc comment names a 180 s budget those sites never
apply. The pilot's "invariant inverted / flake unmitigated" claim, filed upstream as
microsoft/aspire#19540 (open, no maintainer response), does not hold.

So the label was wrong, as V02's was before the runs. On adjudicated labels: 0 true
findings killed, and the refuters corrected two records (V11, and V02's OS attribution:
`libc` entered arborist's pkgMetaKeys in npm v11.11.0, absent in v11.9.0/v11.10.0).

This re-adjudication happened after seeing the result, which is the move a
pre-registration exists to prevent. It rests on cited source lines checked by hand and on
two runs converging, not on preference, but it is still the maintainer judging his own
instrument.

## Predictions that failed

- V01 predicted refuted 2/2, got partly_refuted 2/2: both killed the remedy and kept "a
  second copy of the string exists"; both put the file's own literal idiom (:776) under
  `noticed` instead of using it.
- Expected 7/8 hits, got 6/8.
- Expected V09 or V02 as the likeliest KILL; both held. V11, expected safe, was the one
  refuted, and it was the label that was wrong.

## Limits

13 items, 2 runs each, one model family for reviewer, refuter and adjudicator, findings
reconstructed from case files rather than raw reviewer output, and a corpus whose own
labels were wrong in 2 of 13 items.
