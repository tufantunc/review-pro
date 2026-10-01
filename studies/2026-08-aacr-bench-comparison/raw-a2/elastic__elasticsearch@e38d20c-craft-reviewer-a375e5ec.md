<!-- elastic__elasticsearch@e38d20c craft-reviewer; verbatim final answer -->
- severity: Medium
  category: craft.code-judo
  file: test/framework/src/main/java/org/elasticsearch/test/MockLog.java
  line: 319
  title: PatternAndExceptionSeenEventExpectation copies its parents' matching logic, holds a dead `message` field and uses nested ifs
  evidence: |
    public static class PatternAndExceptionSeenEventExpectation extends SeenEventExpectation {
        private final Pattern pattern;
        private final Class<? extends Exception> clazz;
        private final String exceptionMessage;
        ...
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
                    }
                }
  impact: The new class overrides `match()` and copies the level/logger guard from `AbstractEventExpectation.match` (line 176) and from `PatternSeenEventExpectation.match` (line 300). It copies the thrown-class/message check from `ExceptionSeenEventExpectation.innerMatch` word for word. It also passes the regex string to `super` as `message`, and nothing reads that field afterwards. MockLog now has three separate copies of "level+logger guard, then predicate". A future change to matching (for example, how `Regex.simpleMatch` is handled) has to be made in each copy. The `if (exceptionMatches) { if (patternMatches) ... }` nesting also runs the regex even when the exception check has already failed.
  remedy: Let the class reuse what already exists. Extend `ExceptionSeenEventExpectation` and override only the message part. Better still, add a protected `messageMatches(String formatted)` hook to `AbstractEventExpectation.match` (it is currently hard-wired to simpleMatch/contains). Then the class overrides the hook with `pattern.matcher(formatted).matches()` and inherits `innerMatch` for the exception. That hook would also let `PatternSeenEventExpectation` stop copying the guard, latch and assert methods. At the very least, collapse the nested ifs into one `&&` condition and drop the separate `pattern` field.
  confidence: high
  overlap_hints: [dry.duplication]

- severity: Medium
  category: craft.boundary
  file: test/framework/src/main/java/org/elasticsearch/search/ErrorTraceHelper.java
  line: 68
  title: New helpers reach the cluster through a static global and hardcode one test's exception, unlike the injected style of the existing method
  evidence: |
    public static BooleanSupplier setupErrorTraceListener(InternalTestCluster internalCluster) {   // existing: injected
    ...
    import static org.elasticsearch.test.ESIntegTestCase.internalCluster;
    ...
    Arrays.stream(internalCluster().getNodeNames()).map(ESIntegTestCase::getNodeId).collect(Collectors.joining("|"))
    ...
                    QueryShardException.class,
                    "failed to create query: For input string: \"foo\""
  impact: The enum's existing method takes `InternalTestCluster` as a parameter. The two new methods instead read the static `ESIntegTestCase.internalCluster()`, so the helper class now mixes two ways of getting the cluster, and the new methods quietly depend on being called from inside a running `ESIntegTestCase`. `addSeenLoggingExpectations` has a generic name and a generic `errorTriggeringIndex` parameter. Yet it hardcodes the exception class and message produced by one specific fixture: `simple_query_string "foo"` against a numeric field. If the fixture changes, or a second caller uses a different failing query, this framework helper has to change. The fixture, though, lives in two IT classes in different modules.
  remedy: Pass `InternalTestCluster` in, as `setupErrorTraceListener` already does. Take the expected exception class and message as parameters, or move those fixture constants next to `setupIndexWithDocs` in a shared fixture helper. That keeps the helper about error-trace logging and leaves the specific query failure to the tests.
  confidence: high
  overlap_hints: [tests.maintainability]

- severity: Medium
  category: craft.code-judo
  file: qa/smoke-test-http/src/internalClusterTest/java/org/elasticsearch/http/SearchErrorTraceIT.java
  line: 126
  title: Six copy-paste test bodies that differ only in the error_trace value and seen/unseen; the same pattern repeats in AsyncSearchErrorTraceIT
  evidence: |
    public void testLoggingInSearchFailingQueryErrorTraceDefault() throws IOException {
        int numShards = setupIndexWithDocs();
        Request searchRequest = new Request("POST", "/_search");
        searchRequest.setJsonEntity("""
            { "query": { "simple_query_string" : { "query": "foo", "fields": ["field"] } } }
            """);
        String errorTriggeringIndex = "test2";
        try (var mockLog = MockLog.capture(SearchService.class)) {
            ErrorTraceHelper.addSeenLoggingExpectations(numShards, mockLog, errorTriggeringIndex);
            getRestClient().performRequest(searchRequest);
            mockLog.assertAllExpectationsMatched();
        }
    }
    // testNoLoggingInSearchFailingQueryErrorTraceTrue / ...False / testLoggingInMultiSearch...{Default,True,False}: same body
  impact: The change adds about 150 lines to SearchErrorTraceIT and about 100 to AsyncSearchErrorTraceIT. Most of that repeats the request-building and capture/assert code that the existing six tests in each class already repeat. Each new error-trace scenario now costs another copied block, and the actual difference between tests (the `error_trace` value and whether logging is expected) is hidden inside 20 lines of boilerplate. In the async tests, the copied submit-and-poll loop runs before `MockLog.capture`, so it does nothing for the logging assertion. Only the second `performRequest(searchRequest)` inside the capture is being checked.
  remedy: Pull out the request builders `searchRequest(Boolean errorTrace)` and `multiSearchRequest(Boolean errorTrace)`. Add one `assertDataNodeLogging(Request request, boolean expectSeen)` helper that sets up the index, captures `SearchService`, picks seen or unseen expectations, runs the request and asserts. Each test then becomes one line. In AsyncSearchErrorTraceIT, delete the polling loop that runs before capture, or move it inside the capture if the async completion is what should be verified.
  confidence: high
  overlap_hints: [dry.duplication, tests.flaky]

- severity: Low
  category: craft.abstraction
  file: qa/smoke-test-http/src/internalClusterTest/java/org/elasticsearch/http/SearchErrorTraceIT.java
  line: 48
  title: Logger level is set by hand with `Configurator.setLevel` instead of the existing `@TestLogging` helper
  evidence: |
    @BeforeClass
    public static void setDebugLogLevel() {
        Configurator.setLevel("org.elasticsearch.search.SearchService", Level.DEBUG);
    }
  impact: The same block is copied into AsyncSearchErrorTraceIT:49. A third copy sits inside the try block of SearchServiceTests:186. None of them ever restores the level, so the DEBUG setting leaks into later tests in the same JVM. The framework already has `@TestLogging`, which supports `TYPE` and `METHOD` targets and resets the level automatically. Other ITs use it at class level, for example EsqlActionBreakerIT:43.
  remedy: Replace the `@BeforeClass` methods and the inline call with `@TestLogging(value = "org.elasticsearch.search.SearchService:DEBUG", reason = "...")` on the class, or on the test method in SearchServiceTests. Then remove the log4j `Configurator`/`Level` imports.
  confidence: high
  overlap_hints: [tests.isolation]

- severity: Low
  category: craft.abstraction
  file: server/src/main/java/org/elasticsearch/search/SearchService.java
  line: 545
  title: Static helper takes all of ClusterService just to read the local node id in one log line
  evidence: |
    static <T> ActionListener<T> maybeWrapListenerForStackTrace(
        ActionListener<T> listener,
        ShardSearchRequest request,
        ThreadPool threadPool,
        ClusterService clusterService
    ) {
    ...
     * @param clusterService the cluster service
  impact: All five callers pass the instance fields `threadPool, clusterService` to a static method on the same class. The new parameter widens the method's dependency to a whole service object, and its javadoc ("the cluster service") explains nothing. The test has to build a real ClusterService (`createClusterService(threadPool)`) just to supply a node id string, and it never closes it.
  remedy: Either make the method an instance method, which drops both `threadPool` and `clusterService` from the signature, or pass the narrow value it needs (`String localNodeId` / `DiscoveryNode`). The unit test can then pass a literal, and the javadoc can say what the value is for.
  confidence: medium
  overlap_hints: [tests.resource-leak]

## Files examined
examined: [CONTRIBUTING.md, docs/changelog/125732.yaml, qa/smoke-test-http/src/internalClusterTest/java/org/elasticsearch/http/SearchErrorTraceIT.java, server/src/main/java/org/elasticsearch/action/search/SearchTransportService.java, server/src/main/java/org/elasticsearch/search/SearchService.java, server/src/test/java/org/elasticsearch/search/SearchServiceSingleNodeTests.java, server/src/test/java/org/elasticsearch/search/SearchServiceTests.java, test/framework/src/main/java/org/elasticsearch/search/ErrorTraceHelper.java, test/framework/src/main/java/org/elasticsearch/test/MockLog.java, x-pack/plugin/async-search/src/internalClusterTest/java/org/elasticsearch/xpack/search/AsyncSearchErrorTraceIT.java]
not_examined: []
