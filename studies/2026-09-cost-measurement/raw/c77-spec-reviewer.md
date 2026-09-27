<!-- c77 spec-reviewer; verbatim final answer -->
## Spec findings: none

I checked all four requirements in the spec against `/private/tmp/claude-501/-Users-tufantunc-Desktop-Projects-Personal-review-pro/99075928-604e-433b-bc82-95e9c121edc8/scratchpad/cost/work/c77/repo/docs/internals/releasing.md`, and the diff meets each one:

- **The diagnosis is recorded.** The spec asks for "failed with `E404` on `PUT` after a clean build, test and scan... an expired `NPM_TOKEN` (created 93 days earlier), which npm reports as a 404". The new section "When a publish fails with E404" covers the PUT 404 after a clean build, test and scan, and names the expired token as the cause. It also says "npm reports a rejected publish as a 404" and gives the 93 days.
- **The recovery is recorded.** The spec asks for "a token rotation plus `gh run rerun --failed` from the same tag". Step 1 replaces the `NPM_TOKEN` secret. Step 2 runs `gh run rerun ... --failed` "from the same tag. Do not delete or move the tag".
- **The one-time setup notes that tokens expire.** The spec asks it to note "in the one-time setup, that granular tokens expire". Item 1 of One-time setup now says "Granular tokens expire."
- **Docs only, no release.** Only this one Markdown file changed.

The extra content (the verify step, the provenance note, the expiry-date advice) stays inside the area the spec describes. It adds no dependency, public API, config key or change in behaviour, so it doesn't count as scope creep.
