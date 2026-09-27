```yaml
base: main
active_stacks: []
changed_files_total: 1
changed_files: [core/shared/output-schema.md]
diff_class: trivial
spec_source:
  kind: none
repository_rules:
  source: .review-pro/rules.md@bccb367ecfe22874b59f2aae5d27a15cf8c0a954
  file_changed: none
  rows:
    - id: R4
      line: 32
      when_matched: [core/shared/output-schema.md]
      then_missing: [docs/llms.txt]
      state: judge
      owner: ai-antipatterns
      text: "A change to what review-pro does, as a reader of `docs/llms.txt` would describe it, must be reflected there; no check reads that file."
    - id: R5
      line: 40
      when_matched: [core/shared/output-schema.md]
      then_missing: [cli/README.md]
      state: judge
      owner: ai-antipatterns
      text: "A change to what review-pro does, as the npm package page describes it, must be reflected in `cli/README.md`."
    - id: R7
      line: 58
      when_matched: [core/shared/output-schema.md]
      then_missing: [core/agents/*-reviewer.md]
      state: judge
      owner: correctness
      text: "A rule added to the shared output schema must also be added to the reviewer agent bodies that inline it."
dispatch:
  correctness:
    context:
      changed_files: [core/shared/output-schema.md]
      related: [core/agents/a11y-reviewer.md, core/agents/ai-antipatterns-reviewer.md, core/agents/api-contract-reviewer.md, core/agents/backend-reviewer.md, core/agents/correctness-reviewer.md, core/agents/craft-reviewer.md, core/agents/db-reviewer.md, core/agents/dry-reviewer.md, core/agents/frontend-reviewer.md, core/agents/performance-reviewer.md, core/agents/security-reviewer.md, core/agents/spec-reviewer.md, core/agents/tests-reviewer.md, docs/internals/adr/0001-inline-the-schema-into-agent-bodies.md]
  ai-antipatterns:
    context:
      changed_files: [core/shared/output-schema.md]
      related: [docs/llms.txt, cli/README.md]
  api-contract:
    context:
      changed_files: [core/shared/output-schema.md]
      related: [core/skills/review-pro-synthesize/SKILL.md, core/skills/review-pro-verify/SKILL.md, docs/internals/adr/0001-inline-the-schema-into-agent-bodies.md]
```

**Summary:** One 2-line change to `core/shared/output-schema.md` (trivial, no stacks installed, no spec found). It matches three repository rules still waiting on a judgement (R4, R5, R7), so ai-antipatterns and correctness are dispatched. api-contract is dispatched too, as a precaution: the output schema is a contract.