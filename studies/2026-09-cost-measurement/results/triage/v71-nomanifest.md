Triage is done. The dispatch plan is below.

```yaml
base: main
active_stacks: []
changed_files_total: 28
changed_files: [README.md, core/skills/security/SKILL.md, docs/internals/adr/0008-security-content-names-what-to-flag.md, docs/internals/releasing.md, scripts/validate.sh, scripts/validate.test.sh, stacks/CONTRIBUTING.md, stacks/ai-ml/manifest.json, stacks/ai-ml/security.md, stacks/capacitor/manifest.json, stacks/capacitor/security.md, stacks/dotnet/manifest.json, stacks/dotnet/security.md, stacks/go/security.md, stacks/node/manifest.json, stacks/node/security.md, stacks/php/manifest.json, stacks/php/security.md, stacks/python/manifest.json, stacks/python/security.md, stacks/rust/manifest.json, stacks/rust/security.md, stacks/swift/manifest.json, stacks/swift/security.md, stacks/typescript-react/manifest.json, stacks/typescript-react/security.md, stacks/wordpress/manifest.json, stacks/wordpress/security.md]
diff_class: substantive
spec_source:
  kind: none
external_premises:
  - claim: "onnx below 1.16 follows `external_data` paths out of the model directory (CVE-2024-27318) ... the entry cites every advisory up to onnx 1.21.0, since three landed after 1.16 (CVE-2026-27489, CVE-2026-34446, CVE-2026-34447)"
    cited: CVE-2024-27318, CVE-2026-27489, CVE-2026-34446, CVE-2026-34447 (onnx version floor 1.21.0)
    source: commit-message
    owner: api-contract
  - claim: "the signal line's torch>=2.0 is torch 2.6 (CVE-2025-32434)"
    cited: CVE-2025-32434 (torch weights_only floor 2.6)
    source: commit-message
    owner: api-contract
  - claim: "rust gains sqlx 0.9's `AssertSqlSafe`"
    cited: sqlx 0.9 release (query API accepts dynamic SQL only via AssertSqlSafe)
    source: commit-message
    owner: api-contract
premises_dropped: 2
repository_rules:
  source: .review-pro/rules.md@10c183eb0516c408ad28a2a9dd75e6c16c1ea173
  file_changed: none
  rows:
    - id: R2
      line: 16
      when_matched: [stacks/ai-ml/security.md, stacks/capacitor/security.md, stacks/dotnet/security.md, stacks/go/security.md, stacks/node/security.md, stacks/php/security.md, stacks/python/security.md, stacks/rust/security.md, stacks/swift/security.md, stacks/typescript-react/security.md, stacks/wordpress/security.md]
      then_missing: [stacks/go/manifest.json]
      state: judge
      owner: ai-antipatterns
      text: "A change to a stack pack's files must bump that pack's `manifest.json` version."
    - id: R4
      line: 32
      when_matched: [core/skills/security/SKILL.md]
      then_missing: [docs/llms.txt]
      state: judge
      owner: ai-antipatterns
      text: "A change to what review-pro does, as a reader of `docs/llms.txt` would describe it, must be reflected there; no check reads that file."
    - id: R5
      line: 40
      when_matched: [core/skills/security/SKILL.md]
      then_missing: [cli/README.md]
      state: judge
      owner: ai-antipatterns
      text: "A change to what review-pro does, as the npm package page describes it, must be reflected in `cli/README.md`."
dispatch:
  security:
    context:
      changed_files: [core/skills/security/SKILL.md, stacks/ai-ml/security.md, stacks/capacitor/security.md, stacks/dotnet/security.md, stacks/go/security.md, stacks/node/security.md, stacks/php/security.md, stacks/python/security.md, stacks/rust/security.md, stacks/swift/security.md, stacks/typescript-react/security.md, stacks/wordpress/security.md, docs/internals/adr/0008-security-content-names-what-to-flag.md, stacks/CONTRIBUTING.md, README.md]
      related: [stacks/kotlin/security.md, stacks/nextjs/security.md, stacks/tanstack-start/security.md, stacks/flutter/security.md, stacks/react-native/security.md, core/shared/severity.md, core/agents/security-reviewer.md]
  correctness:
    context:
      changed_files: [scripts/validate.sh, scripts/validate.test.sh, stacks/CONTRIBUTING.md, docs/internals/releasing.md, stacks/ai-ml/manifest.json, stacks/capacitor/manifest.json, stacks/dotnet/manifest.json, stacks/node/manifest.json, stacks/php/manifest.json, stacks/python/manifest.json, stacks/rust/manifest.json, stacks/swift/manifest.json, stacks/typescript-react/manifest.json, stacks/wordpress/manifest.json]
      related: ["stacks/*/*.md (all existing pack files, which must now carry the three base sections)", "stacks/*/manifest.json (unchanged packs)", cli/src/commands/update.ts, cli/src/lib/manifest.ts]
  tests:
    context:
      changed_files: [scripts/validate.test.sh, scripts/validate.sh]
      related: [.github/workflows/]
  craft:
    context:
      changed_files: [core/skills/security/SKILL.md, scripts/validate.sh, scripts/validate.test.sh, stacks/CONTRIBUTING.md, docs/internals/adr/0008-security-content-names-what-to-flag.md, stacks/ai-ml/security.md, stacks/capacitor/security.md, stacks/dotnet/security.md, stacks/go/security.md, stacks/node/security.md, stacks/php/security.md, stacks/python/security.md, stacks/rust/security.md, stacks/swift/security.md, stacks/typescript-react/security.md, stacks/wordpress/security.md]
      related: [core/skills/correctness/SKILL.md, core/shared/severity.md]
  dry:
    context:
      changed_files: [core/skills/security/SKILL.md, stacks/ai-ml/security.md, stacks/capacitor/security.md, stacks/dotnet/security.md, stacks/go/security.md, stacks/node/security.md, stacks/php/security.md, stacks/python/security.md, stacks/rust/security.md, stacks/swift/security.md, stacks/typescript-react/security.md, stacks/wordpress/security.md, scripts/validate.sh, scripts/validate.test.sh, stacks/CONTRIBUTING.md, docs/internals/releasing.md]
      related: [stacks/kotlin/security.md, stacks/nextjs/security.md, stacks/tanstack-start/security.md, core/shared/severity.md, core/agents/security-reviewer.md]
  ai-antipatterns:
    context:
      changed_files: [README.md, core/skills/security/SKILL.md, docs/internals/adr/0008-security-content-names-what-to-flag.md, docs/internals/releasing.md, scripts/validate.sh, scripts/validate.test.sh, stacks/CONTRIBUTING.md, stacks/ai-ml/manifest.json, stacks/ai-ml/security.md, stacks/capacitor/manifest.json, stacks/capacitor/security.md, stacks/dotnet/manifest.json, stacks/dotnet/security.md, stacks/go/security.md, stacks/node/manifest.json, stacks/node/security.md, stacks/php/manifest.json, stacks/php/security.md, stacks/python/manifest.json, stacks/python/security.md, stacks/rust/manifest.json, stacks/rust/security.md, stacks/swift/manifest.json, stacks/swift/security.md, stacks/typescript-react/manifest.json, stacks/typescript-react/security.md, stacks/wordpress/manifest.json, stacks/wordpress/security.md]
      related: [stacks/go/manifest.json, docs/llms.txt, cli/README.md, cli/src/commands/update.ts, .review-pro/rules.md]
  api-contract:
    context:
      changed_files: [stacks/ai-ml/security.md, stacks/rust/security.md, scripts/validate.sh, stacks/CONTRIBUTING.md]
      related: [cli/src/commands/update.ts, cli/src/lib/manifest.ts, "stacks/*/manifest.json"]
```

**Summary:** 28 files changed (the security rubric, 11 security pack files, the validator and its tests, docs) and 7 reviewers dispatched: security, correctness, tests, craft, dry, ai-antipatterns and api-contract. No stacks are installed, so every reviewer runs core-only. No spec was found, so the spec reviewer is not dispatched. Three version-floor premises (onnx, torch, sqlx) go to api-contract, and two are dropped: the DOMPurify advisory count and the Cloudflare source. Three repository rules need a judgement: R2 (the go pack changed without a `manifest.json` bump), R4 (`docs/llms.txt` not updated) and R5 (`cli/README.md` not updated).