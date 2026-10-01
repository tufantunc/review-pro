<!-- elastic__elasticsearch@e38d20c correctness-reviewer; verbatim final answer -->
- severity: Medium
  category: correctness.concurrency
  file: x-pack/plugin/async-search/src/internalClusterTest/java/org/elasticsearch/xpack/search/AsyncSearchErrorTraceIT.java
  line: 180
  title: New async-search logging ITs check the expectations without waiting for the async search to run
  evidence: |
    searchRequest.addParameter("keep_on_completion", "true");
    searchRequest.addParameter("wait_for_completion_timeout", "0ms");
    ...
    try (var mockLog = MockLog.capture(SearchService.class)) {
        ErrorTraceHelper.addSeenLoggingExpectations(numShards, mockLog, errorTriggeringIndex);

        getRestClient().performRequest(searchRequest);
        mockLog.assertAllExpectationsMatched();
    }
  impact: |
    The search inside the MockLog capture is a fresh `_async_search` submit with `wait_for_completion_timeout=0ms`, so the REST call can return before any shard has failed. The earlier submit outside the capture was polled until it finished, but this one is not polled. `assertAllExpectationsMatched()` does not wait: `SeenEventExpectation.assertMatched` only checks `seenLatch.getCount() == 0` (MockLog.java:216-218). Because shard query failures run on search threads, this creates a race:
    - `testLoggingInAsyncSearchFailingQueryErrorTraceDefault` and `testLoggingInAsyncSearchFailingQueryErrorTraceFalse` (line 248) can fail intermittently.
    - `testLoggingInAsyncSearchFailingQueryErrorTraceTrue` (line 214) can pass without testing anything, because the shards may not have run yet when the "not seen" expectation is checked.
  remedy: Use `mockLog.awaitAllExpectationsMatched()` for the "seen" expectations. Also poll the in-capture submission to completion (or move the first submit-and-poll loop inside the `MockLog.capture` block) before asserting. That way the "not seen" assertion runs only after the shards have executed.
  confidence: high
  overlap_hints: [tests.flaky]
  evidence_refs: [test/framework/src/main/java/org/elasticsearch/test/MockLog.java:216, test/framework/src/main/java/org/elasticsearch/test/MockLog.java:113]

- severity: Low
  category: correctness.logic
  file: server/src/main/java/org/elasticsearch/search/SearchService.java
  line: 865
  title: The scroll path now takes the error_trace version from the original request's coordinator, not the node sending the scroll
  evidence: |
    final LegacyReaderContext readerContext = (LegacyReaderContext) findReaderContext(request.contextId(), request);
    final ShardSearchRequest shardSearchRequest = readerContext.getShardSearchRequest(null);
    listener = maybeWrapListenerForStackTrace(listener, shardSearchRequest, threadPool, clusterService);
  impact: |
    Before this change, the check used `channel.getVersion()` of the incoming scroll request. Now it uses the `channelVersion` of the `ShardSearchRequest` stored in the `LegacyReaderContext`. For scroll, `LegacyReaderContext.getShardSearchRequest` (LegacyReaderContext.java:74-75) returns the original query-phase request. Its `channelVersion` was fixed when that first request was deserialized (ShardSearchRequest.java:330).

    A scroll continuation can be coordinated by any node: the scroll id carries the data-node targets (SearchScrollAsyncAction.java:136), so a client can send it to a different node than the one that ran the initial search. During a rolling upgrade across ERROR_TRACE_IN_TRANSPORT_HEADER (8_811_0_00):
    - Initial search via an upgraded node, then `_search/scroll` via a pre-8_811 node. The stored version passes `onOrAfter`, but the old node never sets the `error_trace` thread-context header, so it is read with its default of "false". Stack traces are then stripped from errors sent to an old node. The method's javadoc says old nodes should keep stack traces by defaulting to true.
    - The reverse order: stack traces are kept even though the new coordinator asked for them to be removed.

    The effect is limited to diagnostic detail, during mixed-version clusters, on the scroll path. The QuerySearchRequest and rank-feature paths are not affected because the same coordinator drives every phase of one search.
  remedy: Keep the transport version of the current request for the version check. For example, have `maybeWrapListenerForStackTrace` take a `TransportVersion` plus a `ShardId` (or the request, for logging only), and keep passing `channel.getVersion()` from `SearchTransportService` for the scroll and query-by-id handlers. Use the stored `ShardSearchRequest` only for the `shardId` in the log message.
  confidence: medium
  overlap_hints: [api-contract.bwc]
  evidence_refs: [server/src/main/java/org/elasticsearch/search/internal/LegacyReaderContext.java:74, server/src/main/java/org/elasticsearch/search/internal/ShardSearchRequest.java:330, server/src/main/java/org/elasticsearch/action/search/SearchScrollAsyncAction.java:136, server/src/main/java/org/elasticsearch/action/search/SearchTransportService.java:466]

- severity: Nitpick
  category: correctness.side-effect
  file: server/src/test/java/org/elasticsearch/search/SearchServiceTests.java
  line: 186
  title: Logger level set to DEBUG and never restored, in the unit test and both ITs
  evidence: |
    try (var mockLog = MockLog.capture(SearchService.class)) {
        Configurator.setLevel("org.elasticsearch.search.SearchService", Level.DEBUG);
  impact: The `SearchService` logger stays at DEBUG for the rest of the JVM's life. That includes later test classes running in the same JVM, and the same happens with `@BeforeClass` in SearchErrorTraceIT and AsyncSearchErrorTraceIT. The effect is noisier logs, plus a hidden dependence on test order for any test that assumes the default level.
  remedy: Use `@TestLogging(value = "org.elasticsearch.search.SearchService:DEBUG", reason = ...)`, which restores the level automatically. Or save the previous level and reset it in `@AfterClass` / a finally block.
  confidence: high
  overlap_hints: [tests.isolation]

Points checked with no finding:
- **Exceptions from `findReaderContext`:** they are thrown synchronously. The old wrapped listener never saw them either, so moving the wrap after `findReaderContext` changes nothing.
- **`clusterService.localNode()`:** it is only called inside the lazy debug supplier, on a node that is already serving search requests.
- **`PatternAndExceptionSeenEventExpectation`:** a `getMessage()` NPE could only happen if the thrown exception is exactly the expected class and has a null message. The expected classes (`QueryShardException`, and `Exception` built with a message in the unit test) always carry one.

## Files examined
examined: [server/src/main/java/org/elasticsearch/search/SearchService.java, server/src/main/java/org/elasticsearch/action/search/SearchTransportService.java, test/framework/src/main/java/org/elasticsearch/test/MockLog.java, test/framework/src/main/java/org/elasticsearch/search/ErrorTraceHelper.java, server/src/test/java/org/elasticsearch/search/SearchServiceTests.java, server/src/test/java/org/elasticsearch/search/SearchServiceSingleNodeTests.java, qa/smoke-test-http/src/internalClusterTest/java/org/elasticsearch/http/SearchErrorTraceIT.java, x-pack/plugin/async-search/src/internalClusterTest/java/org/elasticsearch/xpack/search/AsyncSearchErrorTraceIT.java, CONTRIBUTING.md, docs/changelog/125732.yaml]
not_examined: []
