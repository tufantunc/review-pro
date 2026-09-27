```yaml
base: main
active_stacks: []
changed_files_total: 1
changed_files: [stacks/newpack/security.md]
diff_class: trivial
spec_source:
  kind: none
repository_rules:
  source: .review-pro/rules.md@bccb367ecfe22874b59f2aae5d27a15cf8c0a954
  file_changed: none
  rows:
    - id: R2
      line: 16
      when_matched: [stacks/newpack/security.md]
      then_missing: [stacks/newpack/manifest.json]
      state: judge
      owner: ai-antipatterns
      text: "A change to a stack pack's files must bump that pack's `manifest.json` version."
dispatch:
  ai-antipatterns:
    context:
      changed_files: [stacks/newpack/security.md]
      related: [stacks/CONTRIBUTING.md, stacks/README.md, stacks/node/security.md, stacks/node/manifest.json, stacks/python/security.md]
  correctness:
    context:
      changed_files: [stacks/newpack/security.md]
      related: [cli/src/lib/catalog.ts, cli/src/commands/init.ts, cli/src/commands/interactive.ts, cli/build-assets.mjs, scripts/validate.sh, stacks/node/manifest.json]
  dry:
    context:
      changed_files: [stacks/newpack/security.md]
      related: [stacks/node/security.md, stacks/python/security.md, stacks/go/security.md, core/skills/security/SKILL.md]
```

Dispatching 3 reviewers. The diff is one new 3-line pack file, `stacks/newpack/security.md`. That file has no `manifest.json` alongside it, which puts rule R2 in `judge` and sends it to ai-antipatterns. Correctness checks whether the catalog, build and validate steps break on a pack with no manifest. Dry checks for overlap with the existing security packs. No spec was found, because the repo has no git remote.