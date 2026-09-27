<!-- c77 ai-antipatterns-reviewer; verbatim final answer -->
## AI-Antipatterns findings

- severity: Low
  category: ai-antipatterns.hallucination
  file: docs/internals/releasing.md
  line: 134
  title: The edited token step still offers a "classic Automation token", which npm stopped issuing in 2025
  evidence: |
    1. **npm token.** On npmjs.com, Access Tokens, create a Granular Access Token with publish permission scoped to this package, or a classic Automation token. Granular tokens expire. Note the expiry date where the next release will see it, because nothing warns before it passes.
  impact: The diff edits this line and adds "Granular tokens expire", so a classic token now reads as the option that doesn't expire. The new E404 section also points readers here ("Create a new token (see One-time setup)", line 141). npm stopped letting anyone create classic tokens on 2025-11-05 and revoked all existing ones on 2025-12-09. Granular tokens with write permission now last at most 90 days, and new ones default to 7. A maintainer who tries to stop the E404 from recurring by choosing a classic token will find that option doesn't exist. The prose also never says the expiry is a hard 90-day cap. The "93 days earlier" in line 139 is consistent with that cap, so the text is right about expiry but doesn't state the limit or the 7-day default. The damage is small because the reader lands on the granular path anyway.
  remedy: Drop "or a classic Automation token". Say that a write-enabled granular token lasts at most 90 days and defaults to 7, so the expiry has to be set explicitly when the token is created. Optionally mention npm trusted publishing (OIDC) as the way to avoid rotating tokens at all.
  confidence: high
  evidence_refs: [network: https://github.blog/changelog/2025-11-05-npm-security-update-classic-token-creation-disabled-and-granular-token-changes/, network: https://github.blog/changelog/2025-12-09-npm-classic-tokens-revoked-session-based-auth-and-cli-token-management-now-available/]
  overlap_hints: [correctness.broken-existing]

These claims in the new text check out, so there are no findings on them:
- **`gh run rerun <id> --failed`**: exists in local gh 2.101.0 ("Rerun only failed jobs, including dependencies"). That also covers the claim that the skipped `sbom`/`sbom-assets` jobs run on the rerun, since both have `needs: publish` (`.github/workflows/publish.yml:118,189`).
- **`gh run list --workflow=publish.yml --limit 1 --json databaseId -q '.[0].databaseId'`**: `-w/--workflow`, `-L/--limit`, `--json` and `-q/--jq` all exist, and `databaseId` is a valid JSON field.
- **`gh secret list` showing when a secret was last set**: `updatedAt` is one of its JSON fields.
- **The E404 string**: matches how npm builds the message. `npm-registry-fetch/lib/errors.js:41` produces `${status} ${statusText} - ${method} ${uri}`, and npm 11.9.0 `lib/utils/error-message.js:170-172` shows it under the `404` prefix. With the `npm error` log prefix that npm 10+ uses, you get `npm error 404 Not Found - PUT https://registry.npmjs.org/review-pro`.
- **Section shape and cross-references**: the new "When a publish fails with E404" heading matches the existing "When a publish fails on provenance". Its references to "One-time setup" and "step 7" use the same plain-text style as the existing "step 4 insists" (line 158).
- **"nothing warns before it passes"**: I couldn't confirm or disprove this from public npm docs, so I haven't raised it.

## Files examined
examined: [docs/internals/releasing.md, .github/workflows/publish.yml]
not_examined: []

Sources:
- [npm security update: Classic token creation disabled and granular token changes](https://github.blog/changelog/2025-11-05-npm-security-update-classic-token-creation-disabled-and-granular-token-changes/)
- [npm classic tokens revoked, session-based auth and CLI token management now available](https://github.blog/changelog/2025-12-09-npm-classic-tokens-revoked-session-based-auth-and-cli-token-management-now-available/)
- [Strengthening npm security: Important changes to authentication and token management](https://github.blog/changelog/2025-09-29-strengthening-npm-security-important-changes-to-authentication-and-token-management/)
- [Creating and viewing access tokens | npm Docs](https://docs.npmjs.com/creating-and-viewing-access-tokens/)
