```yaml
base: main
active_stacks: []
changed_files_total: 2
changed_files: [stacks/newpack/manifest.json, stacks/newpack/security.md]
diff_class: substantive
spec_source:
  kind: none
repository_rules:
  source: .review-pro/rules.md@bccb367ecfe22874b59f2aae5d27a15cf8c0a954
  file_changed: none
  rows:
    - id: R2
      line: 16
      when_matched: [stacks/newpack/security.md]
      then_missing: []
      state: changed-alongside
      owner: ai-antipatterns
      text: "A change to a stack pack's files must bump that pack's `manifest.json` version."
dispatch:
  api-contract:
    context:
      changed_files: [stacks/newpack/manifest.json, stacks/newpack/security.md]
      related: [stacks/*/manifest.json (sibling manifests, all carry a "reviewers" field), cli/build-assets.mjs, scripts/validate.sh, scripts/validate.test.sh, stacks/CONTRIBUTING.md, manifest.json (reviewer roster)]
  correctness:
    context:
      changed_files: [stacks/newpack/manifest.json, stacks/newpack/security.md]
      related: [cli/build-assets.mjs, scripts/validate.sh, scripts/review.sh, stacks/README.md]
  ai-antipatterns:
    context:
      changed_files: [stacks/newpack/manifest.json, stacks/newpack/security.md]
      related: [stacks/CONTRIBUTING.md, stacks/node/manifest.json, stacks/node/security.md, stacks/README.md]
  security:
    context:
      changed_files: [stacks/newpack/security.md]
      related: [core/skills/security/SKILL.md, stacks/node/security.md]
```

Summary: This is a 2-file change that adds a new stack pack, so it's `substantive`. No stacks are installed and no spec was found. Rule R2 is satisfied because the pack's `manifest.json` changed alongside it. Four reviewers are dispatched: api-contract, correctness, ai-antipatterns and security.