```yaml
base: main
active_stacks: []
changed_files_total: 1
changed_files: [core/skills/security/SKILL.md]
diff_class: trivial
spec_source:
  kind: none
repository_rules:
  source: .review-pro/rules.md@14088fd07a2ba914b7c611a1f232e4bfa5a2ab74
  file_changed: none
  rows:
    - id: R4
      line: 32
      when_matched: [core/skills/security/SKILL.md]
      then_missing: []
      state: no-target
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
  ai-antipatterns:
    context:
      changed_files: [core/skills/security/SKILL.md]
      related: [cli/README.md, .review-pro/rules.md]
```

Summary: One file changed, a 2-line addition to the security skill's prompt, so the diff is trivial. No spec and no external premises were found. I'm dispatching only `ai-antipatterns`, to judge rule R5 because `cli/README.md` wasn't updated. Rule R4 can't fire because `docs/llms.txt` doesn't exist at the merge base.