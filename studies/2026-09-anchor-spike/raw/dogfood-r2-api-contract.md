<!-- commit read: c610017; extracted verbatim from the PR #78 dogfood review's subagent final report -->
- severity: Low
  category: api-contract.schema
  file: README.md
  line: 99
  title: README example lists five receivers for the fixture, but the reviewer that filed the retry.ts finding (and correctness) also received it and is missing
  evidence: |
    Coverage (self-reported): 6 of 7 changed files examined by at least one reviewer, 1 not examined.
      not examined: fixtures/cart-large.json (security: fixture data; backend: fixture data; performance: generated fixture data; frontend: not UI; tests: fixture, no test logic)
    ...
    ### Refuted in verification
    - [Medium] src/lib/retry.ts:1, reimplements the existing `withRetry` helper
  evidence_refs: [core/shared/context-policy.md:3, core/skills/review-pro-synthesize/SKILL.md:55, core/skills/review-pro-triage/SKILL.md:82, core/skills/review-pro-triage/SKILL.md:83]
  impact: context-policy.md:3 says "Baseline for every reviewer: the diff + full contents of changed files", so every dispatched code reviewer is a receiver of fixtures/cart-large.json. The refuted finding ("reimplements the existing withRetry helper") can only come from a dry, ai-antipatterns or craft reviewer (triage:82 routes copy-paste and reuse shapes to those three). None of them is in the detail line. The example's logic changes (a missing ownership check, a useEffect bug) would also dispatch correctness (triage:83), and correctness is missing too. Under the synthesize table ("not examined | every receiver lists it under `not_examined`"), the fixture should either list those reviewers with their reasons or show as `not reported`. As printed, the published example teaches readers the wrong receiver set. The last round fixed this same kind of gap by adding security, backend and frontend; this is what is left of it. Counts (6+1=7; 2 stand + 1 refuted = 3 checked) and header order (Spec, Coverage, Verification) are correct.
  remedy: Add the missing receivers to line 99, for example `dry: fixture data; correctness: generated data, no logic`. Or add `flagged by: backend` to the refuted entry so it no longer implies a sixth reviewer, and state that correctness was not dispatched. The first option is simpler.
  confidence: medium
  overlap_hints: [spec.wrong]

- severity: Low
  category: api-contract.schema
  file: docs-src/i18n/de.json
  line: 96
  title: German docs.run.final uses "Prüfer" for both the independent verifier and the reviewers, merging two roles the English sentence keeps apart
  evidence: |
    "... leitet die relevanten Prüfer-Subagenten mit ihren Stack-Signalen weiter, lässt einen unabhängigen Prüfer bis zu 8 Code-Befunde ab Medium zu widerlegen versuchen, berichtet, welche geänderten Dateien die Prüfer nach eigener Angabe untersucht haben, ..."
  evidence_refs: [docs-src/i18n/en.json:96, cli/README.md:53, docs/de/docs.html]
  impact: de.json uses "Prüfer" for the 13 reviewers everywhere ("Die 13 Prüfer", "Prüfer-Subagenten", "Spezialisten-Prüfer"). So "einen unabhängigen Prüfer" reads as "an independent reviewer", one of the 13, not a separate verifier. The "die Prüfer" that follows in the same sentence can then be read as including it. The English ("independent verifier" vs "the reviewers") and cli/README.md:53 keep the roles apart. So do the other five translations: vérificateur/relecteurs, verifier/reviewers, doğrulayıcı/inceleyiciler, 验证者/审查者, सत्यापक/समीक्षक. German is the only locale where this clause loses the distinction. Every other clause survives in all six translations: up to 8, Medium or higher, code findings, try to refute, self-reported ("nach eigener Angabe", "déclarent", "volgens eigen zeggen", "kendi beyanına göre", "自述", "अपने कथन के अनुसार"), and changed files.
  remedy: Use a distinct noun for the verifier in de.json, for example "lässt einen unabhängigen Verifizierer ..." or "eine unabhängige Gegenprüfung ...", then rebuild docs/de/docs.html with `node scripts/build-site.js`.
  confidence: high
  overlap_hints: []

Checks with no finding:
- (b) I extracted HEAD into the scratchpad, ran `node scripts/build-site.js` there ("wrote 14 pages across 7 languages") and diffed its docs/ against the tree's docs/. There were zero content differences, so all seven docs.html files match the dictionaries.
- (d) Every published surface on the branch describes coverage consistently: README (Why and Architecture bullets), docs/llms.txt, cli/README.md:53, ADR-0010, glossary, reviewer-directive, output-schema. No surface still says the orchestrator carries its own report template. The only remaining "Output template" mentions are in the design spec and validate.sh, and both now describe the synthesis copy as the only one. cli/package.json, the plugin manifests, adapters/opencode/README.md and CONTRIBUTING.md contain no pipeline sentence that needed the new clause.
- (e) The v1.0 contract is extended only. There is one new header line between Spec and Verification, a new appended `## Files examined` section in output-schema.md, and a comment on dispatch `changed_files`. The verdict line, finding fields and existing header lines keep their meaning.

## Files examined
examined: [README.md, core/skills/review-pro-synthesize/SKILL.md, core/skills/review-pro/SKILL.md, docs-src/i18n/de.json, docs-src/i18n/en.json, docs-src/i18n/fr.json, docs-src/i18n/hi.json, docs-src/i18n/nl.json, docs-src/i18n/tr.json, docs-src/i18n/zh.json, docs/superpowers/specs/2026-09-26-coverage-accounting-design.md, scripts/validate.sh, studies/2026-09-coverage-spike/analyze.py]
not_examined:
  - file: docs/docs.html
    reason: checked only by byte-diff against a scratch rebuild from the dictionaries; contents not read directly
  - file: docs/de/docs.html
    reason: checked only by byte-diff against a scratch rebuild from the dictionaries; contents not read directly
  - file: docs/fr/docs.html
    reason: checked only by byte-diff against a scratch rebuild from the dictionaries; contents not read directly
  - file: docs/hi/docs.html
    reason: checked only by byte-diff against a scratch rebuild from the dictionaries; contents not read directly
  - file: docs/nl/docs.html
    reason: checked only by byte-diff against a scratch rebuild from the dictionaries; contents not read directly
  - file: docs/tr/docs.html
    reason: checked only by byte-diff against a scratch rebuild from the dictionaries; contents not read directly
  - file: docs/zh/docs.html
    reason: checked only by byte-diff against a scratch rebuild from the dictionaries; contents not read directly
  - file: scripts/validate.test.sh
    reason: test harness, outside the api-contract concern; only its stat and three grep-matched lines seen
