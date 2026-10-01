<!-- elastic__elasticsearch@e38d20c ai-antipatterns-reviewer; verbatim final answer -->
I found three issues: one Medium and two Low. Every API the brief asked about exists. Nothing in the change calls a method, symbol or import that isn't in the repo, and it adds no dependencies, config keys or env keys.

What I checked against the repo:
- `ESIntegTestCase.internalCluster()` (`ESIntegTestCase.java:635`) and `ESIntegTestCase.getNodeId(String)` (`ESIntegTestCase.java:1169`) are both `public static`.
- `ClusterServiceUtils.createClusterService(ThreadPool)` is at `ClusterServiceUtils.java:110`. Its local node is `DiscoveryNodeUtils.create("node", "node")`, so the `[node]` expectation in `SearchServiceTests` is correct.
- `org.elasticsearch.common.Strings.format` is at `Strings.java:942`.
- `MockLog.capture`, `SeenEventExpectation` and `UnseenEventExpectation` all exist.
- The `SearchService` fields `clusterService` (line 297) and `logger` exist, and `logger.debug(() -> format(...), e)` is a common pattern in `server/src/main` (66 uses).
- The `CONTRIBUTING.md` change is correct. `org.elasticsearch.test.MockLogAppender` no longer exists; the only remaining mention is a stale javadoc `{@link}` in `x-pack/plugin/transform/src/test/java/org/elasticsearch/xpack/transform/notifications/MockTransformAuditor.java:39`.

- severity: Medium
  category: ai-antipatterns.ignored-convention
  file: qa/smoke-test-http/src/internalClusterTest/java/org/elasticsearch/http/SearchErrorTraceIT.java
  line: 49
  title: Raw Configurator.setLevel with no reset is used instead of the repo's @TestLogging annotation
  evidence: |
    @BeforeClass
    public static void setDebugLogLevel() {
        Configurator.setLevel("org.elasticsearch.search.SearchService", Level.DEBUG);
    }
  impact: The code assumes that raising a logger's level once per test class is harmless. In this repo, test logger levels are set with `@TestLogging(value = "logger:LEVEL", reason = ...)`, which has 87 users in test sources. Its `LoggingListener` (`test/framework/src/main/java/org/elasticsearch/test/junit/listeners/LoggingListener.java:58-72,174-177`) saves the previous level and restores it when the test or class finishes, using `Loggers.setLevel`. Here nothing resets the level, so `SearchService` stays at DEBUG for every later test class in the same reused test JVM. The same pattern appears in `x-pack/plugin/async-search/src/internalClusterTest/java/org/elasticsearch/xpack/search/AsyncSearchErrorTraceIT.java:50` and inside the method body in `server/src/test/java/org/elasticsearch/search/SearchServiceTests.java:186`. Only 6 raw `Configurator.setLevel` calls exist in test sources, and the existing non-evil one either resets the level itself (`SettingsFilterTests:114,125`) or uses its own logger name (`RestResponseTests:71`).
  remedy: Delete the `@BeforeClass` methods and the inline `setLevel` call. Annotate the two IT classes, or `testMaybeWrapListenerForStackTraceLogs`, with `@TestLogging(value = "org.elasticsearch.search.SearchService:DEBUG", reason = "verify stack trace logged before clearing")`. Then drop the `Configurator` and `Level` imports where they are no longer used.
  confidence: high
  evidence_refs: [test/framework/src/main/java/org/elasticsearch/test/junit/annotations/TestLogging.java:29, test/framework/src/main/java/org/elasticsearch/test/junit/listeners/LoggingListener.java:58, server/src/test/java/org/elasticsearch/common/settings/SettingsFilterTests.java:125]
  overlap_hints: [tests.flaky, craft.canonical-helper]

- severity: Low
  category: ai-antipatterns.ignored-convention
  file: test/framework/src/main/java/org/elasticsearch/test/MockLog.java
  line: 340
  title: New expectation overrides match() and skips the existing innerMatch hook, copying the pattern and exception logic
  evidence: |
    public PatternAndExceptionSeenEventExpectation(...) {
        super(name, logger, level, pattern);
        this.pattern = Pattern.compile(pattern);
    ...
    @Override
    public void match(LogEvent event) {
        if (event.getLevel().equals(level) && event.getLoggerName().equals(logger)) {
            boolean patternMatches = pattern.matcher(event.getMessage().getFormattedMessage()).matches();
            boolean exceptionMatches = event.getThrown() != null
                && event.getThrown().getClass() == clazz
                && event.getThrown().getMessage().equals(exceptionMessage);
            if (exceptionMatches) {
                if (patternMatches) {
                    seenLatch.countDown();
  impact: |
    `MockLog` already provides the pieces this class rebuilds:
    - an extension point, `AbstractEventExpectation.innerMatch(LogEvent)` (line 190);
    - `ExceptionSeenEventExpectation` (line 257), whose exception check is the same three-line clause, copied here word for word;
    - `PatternSeenEventExpectation` (line 284), which handles the regex case.
    The new class passes the regex to `super` as `message`, where it is never used because `match` is overridden. It also evaluates `patternMatches` eagerly and nests two ifs that mean `exceptionMatches && patternMatches`. The result is a third copy of the matching logic that drifts from the class's own structure.
  remedy: Make the class extend `ExceptionSeenEventExpectation` so the exception check is reused. Then override `match` with one condition, `level && logger && innerMatch(event) && pattern.matcher(...).matches()`, and stop passing the regex as the unused `message`. Alternatively, write the condition as a single `&&` expression.
  confidence: high
  evidence_refs: [test/framework/src/main/java/org/elasticsearch/test/MockLog.java:190, test/framework/src/main/java/org/elasticsearch/test/MockLog.java:257, test/framework/src/main/java/org/elasticsearch/test/MockLog.java:284]
  overlap_hints: [dry.canonical-helper, craft.abstraction]

- severity: Low
  category: ai-antipatterns.ignored-convention
  file: server/src/test/java/org/elasticsearch/search/SearchServiceTests.java
  line: 212
  title: Started ClusterService is created inline and never closed
  evidence: |
    listener = maybeWrapListenerForStackTrace(listener, shardRequest, threadPool, createClusterService(threadPool));
  impact: `createClusterService` returns a ClusterService that has already been started (`ClusterServiceUtils.java:153`, `clusterService.start()`). Elsewhere in the repo the result is either kept in a field and closed in teardown, or wrapped in try-with-resources, for example `TransportResyncReplicationActionTests.java:92` (`try (ClusterService clusterService = createClusterService(threadPool))`). Here a started service is created and dropped in each test, at this line and at line 165. The code only needs `localNode().getId()`.
  remedy: Use `try (ClusterService clusterService = createClusterService(threadPool)) { ... }` in both tests, or create it once in setUp and close it in tearDown.
  confidence: medium
  evidence_refs: [test/framework/src/main/java/org/elasticsearch/test/ClusterServiceUtils.java:153, server/src/test/java/org/elasticsearch/action/resync/TransportResyncReplicationActionTests.java:92]
  overlap_hints: [tests.resource-leak]

## Files examined
examined: [CONTRIBUTING.md, docs/changelog/125732.yaml, qa/smoke-test-http/src/internalClusterTest/java/org/elasticsearch/http/SearchErrorTraceIT.java, server/src/main/java/org/elasticsearch/action/search/SearchTransportService.java, server/src/main/java/org/elasticsearch/search/SearchService.java, server/src/test/java/org/elasticsearch/search/SearchServiceSingleNodeTests.java, server/src/test/java/org/elasticsearch/search/SearchServiceTests.java, test/framework/src/main/java/org/elasticsearch/search/ErrorTraceHelper.java, test/framework/src/main/java/org/elasticsearch/test/MockLog.java, x-pack/plugin/async-search/src/internalClusterTest/java/org/elasticsearch/xpack/search/AsyncSearchErrorTraceIT.java]
not_examined: []
