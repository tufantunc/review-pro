<!-- elastic__elasticsearch@e38d20c dry-reviewer; verbatim final answer -->
## DRY findings

- severity: Medium
  category: dry.canonical-helper
  file: test/framework/src/main/java/org/elasticsearch/test/MockLog.java
  line: 319
  title: PatternAndExceptionSeenEventExpectation copies the matching logic of ExceptionSeenEventExpectation and PatternSeenEventExpectation
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
  evidence_refs: [test/framework/src/main/java/org/elasticsearch/test/MockLog.java:257, test/framework/src/main/java/org/elasticsearch/test/MockLog.java:276, test/framework/src/main/java/org/elasticsearch/test/MockLog.java:284, test/framework/src/main/java/org/elasticsearch/test/MockLog.java:300, test/framework/src/main/java/org/elasticsearch/test/MockLog.java:177]
  impact: The exception check is copied word for word from `ExceptionSeenEventExpectation.innerMatch` (MockLog.java:276-280). The regex check and the level/logger guard are copied from `PatternSeenEventExpectation.match` (MockLog.java:300-306). The class also overrides `AbstractEventExpectation.match` (MockLog.java:177) completely. That makes the `message` field it passes to `super(...)` dead, and leaves the inherited `innerMatch` hook unused. A future fix to exception or pattern matching, such as a null-safe `getMessage()`, has to be made in three places.
  remedy: Reuse what already exists. One option is to extend `ExceptionSeenEventExpectation` and override only the message comparison, for example by adding a protected `messageMatches(LogEvent)` hook to `AbstractEventExpectation` (MockLog.java:177-187) that a regex variant overrides. Another is to keep `SeenEventExpectation` and override `innerMatch` with `ExceptionSeenEventExpectation`'s exception predicate plus the pattern check, so the inherited `match` keeps the level/logger guard. Either way, the hand-written `match` override and its nested `if`s go away.
  confidence: high
  overlap_hints: [craft.abstraction, ai-antipatterns.ignored-convention]

- severity: Medium
  category: dry.canonical-helper
  file: qa/smoke-test-http/src/internalClusterTest/java/org/elasticsearch/http/SearchErrorTraceIT.java
  line: 47
  title: Hand-written Configurator.setLevel in @BeforeClass duplicates the repo's @TestLogging annotation (three copies)
  evidence: |
    @BeforeClass
    public static void setDebugLogLevel() {
        Configurator.setLevel("org.elasticsearch.search.SearchService", Level.DEBUG);
    }
  evidence_refs: [x-pack/plugin/async-search/src/internalClusterTest/java/org/elasticsearch/xpack/search/AsyncSearchErrorTraceIT.java:48, server/src/test/java/org/elasticsearch/search/SearchServiceTests.java:186, test/framework/src/main/java/org/elasticsearch/test/junit/annotations/TestLogging.java:29, modules/transport-netty4/src/internalClusterTest/java/org/elasticsearch/http/netty4/Netty4ChunkedContinuationsIT.java]
  impact: The same logger-level line appears three times: in SearchErrorTraceIT:49, AsyncSearchErrorTraceIT:50 and inside the test body at SearchServiceTests:186. None of the copies resets the level afterwards, so DEBUG stays on for later suites in the same JVM. The framework's `@TestLogging` annotation (TestLogging.java:29, used in about 90 files including internalClusterTest ITs) already sets the level and restores it.
  remedy: Delete the `@BeforeClass setDebugLogLevel()` methods and the inline `Configurator.setLevel` call. Annotate the classes, or `testMaybeWrapListenerForStackTraceLogs`, with `@TestLogging(value = "org.elasticsearch.search.SearchService:DEBUG", reason = "check stack-trace-clearing debug log")`.
  confidence: high
  overlap_hints: [ai-antipatterns.ignored-convention, tests.flaky]

- severity: Medium
  category: dry.copy-paste
  file: x-pack/plugin/async-search/src/internalClusterTest/java/org/elasticsearch/xpack/search/AsyncSearchErrorTraceIT.java
  line: 727
  title: The three new async logging tests copy the submit-and-poll block of the existing tests
  evidence: |
    Request searchRequest = new Request("POST", "/_async_search");
    searchRequest.setJsonEntity("""
        { "query": { "simple_query_string" : { "query": "foo", "fields": ["field"] } } }
        """);
    searchRequest.addParameter("keep_on_completion", "true");
    searchRequest.addParameter("wait_for_completion_timeout", "0ms");
    Map<String, Object> responseEntity = performRequestAndGetResponseEntityAfterDelay(searchRequest, TimeValue.ZERO);
    String asyncExecutionId = (String) responseEntity.get("id");
    Request request = new Request("GET", "/_async_search/" + asyncExecutionId);
    while (responseEntity.get("is_running") instanceof Boolean isRunning && isRunning) {
        responseEntity = performRequestAndGetResponseEntityAfterDelay(request, TimeValue.timeValueSeconds(1L));
    }
  evidence_refs: [x-pack/plugin/async-search/src/internalClusterTest/java/org/elasticsearch/xpack/search/AsyncSearchErrorTraceIT.java:71, x-pack/plugin/async-search/src/internalClusterTest/java/org/elasticsearch/xpack/search/AsyncSearchErrorTraceIT.java:95, x-pack/plugin/async-search/src/internalClusterTest/java/org/elasticsearch/xpack/search/AsyncSearchErrorTraceIT.java:121]
  impact: About 20 lines are repeated in testLoggingInAsyncSearchFailingQueryErrorTrace{Default,True,False} (lines 727, 759, 793). These are near-copies of testAsyncSearchFailingQueryErrorTrace{Default,True,False} (lines 71, 95, 121). The new tests differ only in one `error_trace` value and the final assertion, so the file now holds six copies of the same request-and-poll logic.
  remedy: Extract a `private void submitAndAwaitAsyncSearch(@Nullable String errorTrace)` helper (or one that returns the Request), then call it from both the existing and the new tests. Better still, merge each pair: for example, have testAsyncSearchFailingQueryErrorTraceDefault also check the MockLog expectations instead of adding a parallel test.
  confidence: high
  overlap_hints: [craft.code-judo, tests.structure]

- severity: Medium
  category: dry.copy-paste
  file: qa/smoke-test-http/src/internalClusterTest/java/org/elasticsearch/http/SearchErrorTraceIT.java
  line: 123
  title: The six new logging tests copy the request construction of the six existing error-trace tests
  evidence: |
    Request searchRequest = new Request("POST", "/_search");
    searchRequest.setJsonEntity("""
        {
            "query": {
                "simple_query_string" : {
                    "query": "foo",
                    "fields": ["field"]
                }
            }
        }
        """);
    ...
    MultiSearchRequest multiSearchRequest = new MultiSearchRequest().add(
        new SearchRequest("test*").source(new SearchSourceBuilder().query(simpleQueryStringQuery("foo").field("field")))
    );
    Request searchRequest = new Request("POST", "/_msearch");
    byte[] requestBody = MultiSearchRequest.writeMultiLineFormat(multiSearchRequest, contentType.xContent());
  evidence_refs: [qa/smoke-test-http/src/internalClusterTest/java/org/elasticsearch/http/SearchErrorTraceIT.java:70, qa/smoke-test-http/src/internalClusterTest/java/org/elasticsearch/http/SearchErrorTraceIT.java:88, qa/smoke-test-http/src/internalClusterTest/java/org/elasticsearch/http/SearchErrorTraceIT.java:107]
  impact: The `_search` JSON body now appears six times in the file, and the `_msearch` body plus NByteArrayEntity setup also appears six times. The new tests differ from the existing testSearchFailingQueryErrorTrace* / testMultiSearchFailingQueryErrorTrace* only in their assertion. Changing the failing query means editing 12 places.
  remedy: Add `private Request searchRequest(@Nullable String errorTrace)` and `private Request multiSearchRequest(@Nullable String errorTrace)` helpers and use them from all tests. The cleaner option is to fold the MockLog assertions into the existing tests, which already run the same request, so the parallel testLogging* methods are not needed. The same request-building pattern is also in AsyncSearchErrorTraceIT, so a shared builder in `ErrorTraceHelper` is a reasonable place for it.
  confidence: high
  overlap_hints: [craft.code-judo]

- severity: Low
  category: dry.copy-paste
  file: x-pack/plugin/async-search/src/internalClusterTest/java/org/elasticsearch/xpack/search/AsyncSearchErrorTraceIT.java
  line: 57
  title: setupIndexWithDocs is copied verbatim between the two ITs and edited the same way in both
  evidence: |
    private int setupIndexWithDocs() {
        int numShards = between(DEFAULT_MIN_NUM_SHARDS, DEFAULT_MAX_NUM_SHARDS);
        createIndex("test1", Settings.builder().put(IndexMetadata.SETTING_NUMBER_OF_SHARDS, numShards).build());
        createIndex("test2", Settings.builder().put(IndexMetadata.SETTING_NUMBER_OF_SHARDS, numShards).build());
        indexRandom(
            true,
            prepareIndex("test1").setId("1").setSource("field", "foo"),
            prepareIndex("test2").setId("10").setSource("field", 5)
        );
        refresh();
        return numShards;
    }
  evidence_refs: [qa/smoke-test-http/src/internalClusterTest/java/org/elasticsearch/http/SearchErrorTraceIT.java:57]
  impact: This change made the same edit to both copies (SearchErrorTraceIT:57-68 and AsyncSearchErrorTraceIT:57-69). The fixture is tightly coupled to `ErrorTraceHelper.addSeenLoggingExpectations`, which hardcodes index "test2" and the QueryShardException message for the "foo" value. If one copy drifts, that helper's expectations break silently.
  remedy: Move the fixture next to the expectations it serves, e.g. `ErrorTraceHelper.setupIndexWithDocs(ESIntegTestCase)` returning numShards. Alternatively, have ErrorTraceHelper own the index names and docs as constants that both ITs use.
  confidence: medium
  overlap_hints: [craft.abstraction]

- severity: Low
  category: dry.duplication
  file: server/src/test/java/org/elasticsearch/search/SearchServiceTests.java
  line: 173
  title: The new test builds the same ShardSearchRequest as testMaybeWrapListenerForStackTrace, and doTestCanMatch builds a near-identical one
  evidence: |
    ShardSearchRequest shardRequest = new ShardSearchRequest(
        OriginalIndices.NONE,
        new SearchRequest().allowPartialSearchResults(false).source(new SearchSourceBuilder().query(new MatchAllQueryBuilder())),
        new ShardId(index, index, shardId),
        0,
        1,
        AliasFilter.EMPTY,
        1.0f,
        0,
        null
    );
  evidence_refs: [server/src/test/java/org/elasticsearch/search/SearchServiceTests.java:132, server/src/test/java/org/elasticsearch/search/SearchServiceTests.java:224]
  impact: The file now has three 11-line constructor calls (lines 132, 173, 224). Two are identical and the third differs only in the SearchRequest and the shard count. Any change to the ShardSearchRequest constructor signature means editing all three.
  remedy: Add `private static ShardSearchRequest shardRequest(SearchRequest searchRequest, int numShards)` (with ShardId "index"/0) and use it from both maybeWrap tests and from doTestCanMatch.
  confidence: high
  overlap_hints: [craft.code-judo]

- severity: Low
  category: dry.duplication
  file: server/src/test/java/org/elasticsearch/search/SearchServiceTests.java
  line: 481
  title: The expectation for the stack-trace-clearing log is written out again instead of shared with ErrorTraceHelper
  evidence: |
    new MockLog.PatternAndExceptionSeenEventExpectation(
        format("Tracking information ([node][%s][%d]) and exception logged before stack trace cleared", index, shardId),
        SearchService.class.getCanonicalName(),
        Level.DEBUG,
        format("\\[node\\]\\[%s\\]\\[%d\\] Clearing stack trace before transport:", index, shardId),
        Exception.class,
        exceptionMessage
    )
  evidence_refs: [test/framework/src/main/java/org/elasticsearch/search/ErrorTraceHelper.java:562, test/framework/src/main/java/org/elasticsearch/search/ErrorTraceHelper.java:600, server/src/main/java/org/elasticsearch/search/SearchService.java:557]
  impact: The production format `"[%s]%s Clearing stack trace before transport:"` (SearchService.java:557, via the `logger.debug(...)` call added in this change) is restated as three independent literals. Two are escaped regexes (SearchServiceTests:486 and ErrorTraceHelper:572) and one is an unescaped literal (ErrorTraceHelper:600). If the log message is reworded, all three must be updated by hand. The unseen variant would then silently stop guarding anything.
  remedy: Add one factory in ErrorTraceHelper, e.g. `stackTraceClearedExpectation(String nodeRegex, String index, int shard, Class<? extends Exception>, String msg)`, and call it from both `addSeenLoggingExpectations` and SearchServiceTests. Ideally derive the pattern from a shared constant for the message prefix instead of repeating the literal.
  confidence: medium
  overlap_hints: [tests.brittle]

## Files examined
examined: [CONTRIBUTING.md, docs/changelog/125732.yaml, qa/smoke-test-http/src/internalClusterTest/java/org/elasticsearch/http/SearchErrorTraceIT.java, server/src/main/java/org/elasticsearch/action/search/SearchTransportService.java, server/src/main/java/org/elasticsearch/search/SearchService.java, server/src/test/java/org/elasticsearch/search/SearchServiceSingleNodeTests.java, server/src/test/java/org/elasticsearch/search/SearchServiceTests.java, test/framework/src/main/java/org/elasticsearch/search/ErrorTraceHelper.java, test/framework/src/main/java/org/elasticsearch/test/MockLog.java, x-pack/plugin/async-search/src/internalClusterTest/java/org/elasticsearch/xpack/search/AsyncSearchErrorTraceIT.java]
not_examined: []
