<!-- c77 correctness-reviewer; verbatim final answer -->
## Correctness findings: none

I checked every instruction and factual claim in the new section against `.github/workflows/publish.yml` and the rest of the runbook. A maintainer who follows them would recover correctly.

- **"Release and SBOM run after Publish, skipped then rerun":** holds. "Create GitHub Release" is a step after "Publish" in the same `publish` job (publish.yml:94-107). `sbom` (`needs: publish`, :118) and `sbom-assets` (`needs: sbom`, :189) are separate jobs, so a failed `publish` skips them. `gh run rerun --failed` reruns the failed jobs and the jobs that depend on them, which is the mechanism the workflow's own comment relies on (:111-112). The text calls them "SBOM steps" when they are jobs, but the result it describes is right. The failed attempt never reached `gh release create`, so the rerun does not collide with an existing release.
- **Rerun command:** works. `--workflow=publish.yml` names the right file. `-q` is paired with `--json` as it must be. The trigger is only `push: tags: ['v*']` (:5-7), and a rerun keeps the original tag ref and SHA, so "rerun from the same tag" is accurate. `--limit 1` picks the newest run of the workflow. That run is the failed one unless another `v*` tag was pushed in between, which a maintainer fixing a failed release would not do. Reruns are new attempts of the same run ID, so a second rerun also finds the right run.
- **Token fix before rerun:** the job reads `secrets.NPM_TOKEN` when it runs (:98), so a rerun picks up the replaced secret. `gh secret list` prints an updated-at column, so "shows when it was last set" holds.
- **"Verify as in step 7":** correct. Step 7 is "Verify what actually shipped" (releasing.md:98).
- **Provenance claim:** consistent with the workflow. `npm publish --provenance` (:96) signs and records the provenance statement before it sends the PUT, so a PUT that returns 404 leaves an entry for a tarball the registry never accepted. The rerun makes a new one. I did not open the npm CLI source for this; it is a known fact about how npm works.
- **Addition to One-time setup:** says granular tokens expire and to note the date. Accurate, and it changes no procedure.

## Files examined
examined: [docs/internals/releasing.md]
not_examined: []
