```yaml
base: main
active_stacks: []
changed_files_total: 1
changed_files: [docs-src/i18n/tr.json]
diff_class: trivial
spec_source:
  kind: none
repository_rules:
  source: .review-pro/rules.md@bccb367ecfe22874b59f2aae5d27a15cf8c0a954
  file_changed: none
  rows:
    - id: R1
      line: 8
      when_matched: [docs-src/i18n/tr.json]
      then_missing: [docs/index.html, docs/docs.html, docs/*/index.html, docs/*/docs.html]
      state: judge
      owner: ai-antipatterns
      text: "A change to the site sources must be rebuilt into `docs/` in the same change."
dispatch:
  ai-antipatterns:
    context:
      changed_files: [docs-src/i18n/tr.json]
      related: [.review-pro/rules.md@bccb367 (R1), docs/tr/index.html, docs/tr/docs.html, CONTRIBUTING.md (site rebuild step)]
  frontend:
    context:
      changed_files: [docs-src/i18n/tr.json]
      related: [docs-src/i18n/en.json, docs-src/i18n/de.json, docs-src/index.html]
```

The only change is one line in the Turkish site title in `docs-src/i18n/tr.json`, and it adds a double space. No `.review-pro/` stacks are installed and no spec was found, so the spec reviewer is skipped. `ai-antipatterns` is dispatched to judge rule R1, because `docs/` wasn't rebuilt. `frontend` is dispatched to check the user-facing i18n string.