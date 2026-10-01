<!-- alibaba__spring-ai-alibaba@4bc7305 db-reviewer; verbatim final answer -->
## DB findings

- severity: High
  category: db.data-loss
  file: spring-ai-alibaba-jmanus/src/main/java/com/alibaba/cloud/ai/example/manus/dynamic/agent/service/AgentServiceImpl.java
  line: 200
  title: Saving an agent now overwrites any stored legacy systemPrompt with " ", and the merged text is never kept
  evidence: |
    if (entity.getSystemPrompt() != null || !entity.getSystemPrompt().trim().isEmpty()) {
        String systemPrompt = entity.getSystemPrompt();
        String nextPrompt = entity.getNextStepPrompt();
        if (nextPrompt != null && !nextPrompt.trim().isEmpty()) {
            nextPrompt = systemPrompt + "\n" + nextPrompt;   // local only, never written back
        }
        log.warn(... agentName, nextPrompt);
        entity.setSystemPrompt(" ");
    }
  impact: `updateAgent` (lines 116-119) loads the row, runs `updateEntityFromConfig` → `mergePrompts`, replaces `nextStepPrompt` with `config.getNextStepPrompt()` (line 169), then saves. The merged string `systemPrompt + "\n" + nextPrompt` only goes into a local variable and a log line. On an existing H2 database, the `system_prompt` column is still NOT NULL (see the next finding). Before this change, `setSystemPrompt(null)` failed that constraint at save time, so the legacy text stayed in the row. With `" "`, the save succeeds, so the first update of any agent that still holds legacy system-prompt text replaces it with `" "` for good. It is not copied into `nextStepPrompt` either: the UI's `nextStepPrompt` comes from `mapToAgentConfig`, which also throws the merge away. There is no backup or audit copy. The log warning says the content is being merged ("本次将agent 的内容合并"), but it is not. The only place the old text survives is the WARN log.
  remedy: Before the destructive write becomes possible, migrate the data. Either assign the merged value back (`entity.setNextStepPrompt(nextPrompt)`) before clearing `systemPrompt`, or run a one-time backfill that runs `UPDATE dynamic_agents SET next_step_prompt = CONCAT(system_prompt, '\n', next_step_prompt) WHERE TRIM(system_prompt) <> ''` and only then clears `system_prompt`. Also fix the guard at line 190 to `!= null && !trim().isEmpty()` so rows that are already blank are not reprocessed.
  confidence: medium
  overlap_hints: [correctness.logic, backend.transaction]
  evidence_refs: [spring-ai-alibaba-jmanus/src/main/java/com/alibaba/cloud/ai/example/manus/dynamic/agent/service/AgentServiceImpl.java:116, spring-ai-alibaba-jmanus/src/main/java/com/alibaba/cloud/ai/example/manus/dynamic/agent/service/AgentServiceImpl.java:153, spring-ai-alibaba-jmanus/src/main/java/com/alibaba/cloud/ai/example/manus/dynamic/agent/service/AgentServiceImpl.java:168]

- severity: Low
  category: db.constraint
  file: spring-ai-alibaba-jmanus/src/main/java/com/alibaba/cloud/ai/example/manus/dynamic/agent/entity/DynamicAgentEntity.java
  line: 45
  title: Removing `nullable = false` changes only new databases; existing ones keep NOT NULL, so the schema now differs by install age
  evidence: |
    @Column(length = 40000)
    @Deprecated
    private String systemPrompt = " ";
  impact: The schema is managed only by `spring.jpa.hibernate.ddl-auto: update` (application.yml:27). There is no Flyway or Liquibase, and no `*.sql` files in the module. Hibernate's `update` mode never relaxes constraints on existing columns, so every existing `./h2-data/openmanus_db` keeps `system_prompt ... NOT NULL`, while new installs get a nullable column. The code still works on old databases only because it writes `" "` everywhere. That includes `DynamicAgentScanner.saveDynamicAgent` (DynamicAgentScanner.java:96-106), which relies on the field initializer. On new databases a NULL `system_prompt` row (written via h2-console or by a future `setSystemPrompt(null)`) replaces the `" "` initializer when the row loads. Line 190 of AgentServiceImpl.java then throws an NPE, through `null.trim()` behind the inverted `||` guard, from `getAllAgents`, `getAgentById`, `createAgent` and `updateAgent`. The only readers of `getSystemPrompt()` are `mergePrompts` (lines 190-191) and `mapToAgentConfig` (line 157).
  remedy: Pick one target schema and apply it explicitly. Either keep `nullable = false` (the `" "` sentinel already satisfies it), or add a versioned migration (`ALTER TABLE dynamic_agents ALTER COLUMN system_prompt SET NULL`) so old and new databases match. In either case, make `mergePrompts` null-safe (`!= null && !trim().isEmpty()`).
  confidence: high
  overlap_hints: [correctness.logic]
  evidence_refs: [spring-ai-alibaba-jmanus/src/main/resources/application.yml:27, spring-ai-alibaba-jmanus/src/main/java/com/alibaba/cloud/ai/example/manus/dynamic/agent/service/AgentServiceImpl.java:190, spring-ai-alibaba-jmanus/src/main/java/com/alibaba/cloud/ai/example/manus/dynamic/agent/service/DynamicAgentScanner.java:96]

## Files examined
examined: [spring-ai-alibaba-jmanus/pom.xml, spring-ai-alibaba-jmanus/src/main/java/com/alibaba/cloud/ai/example/manus/dynamic/agent/entity/DynamicAgentEntity.java, spring-ai-alibaba-jmanus/src/main/java/com/alibaba/cloud/ai/example/manus/dynamic/agent/service/AgentServiceImpl.java]
not_examined: []
