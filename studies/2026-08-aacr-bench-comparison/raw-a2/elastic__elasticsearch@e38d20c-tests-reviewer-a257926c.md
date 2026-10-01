<!-- elastic__elasticsearch@e38d20c tests-reviewer; verbatim final answer -->
- severity: High
  category: tests.flakiness
  file: x-pack/plugin/async-search/src/internalClusterTest/java/org/elasticsearch/xpack/search/AsyncSearchErrorTraceIT.java
  line: 754
  title: Async logging tests check the log too early, before shard execution has run, so they race
  evidence: |
            searchRequest.addParameter("keep_on_completion", "true");
            searchRequest.addParameter("wait_for_completion_timeout", "0ms");
            ...
            try (var mockLog = MockLog.capture(SearchService.class)) {
                ErrorTraceHelper.addSeenLoggingExpectations(numShards, mockLog, errorTriggeringIndex);

                getRestClient().performRequest(searchRequest);
                mockLog.assertAllExpectationsMatched();
            }
  impact: The request inside the capture block is a new `_async_search` submit with `wait_for_completion_timeout=0ms`. It returns as soon as the task is registered, not when the shard queries finish. `assertAllExpectationsMatched()` then reads the latch once without waiting (`SeenEventExpectation.assertMatched` asserts `seenLatch.getCount() == 0`, MockLog.java:216). So:
    - The seen tests (lines 754 and 822) race the data-node shard failures. Each run expects 1 to 10 shards to have logged, and any of them may not have yet.
    - The unseen test (line 788) can pass for the wrong reason: it checks before any shard has run, so it would also pass if `error_trace=true` stopped suppressing the log.
    - The first submit and the GET polling loop run before `MockLog.capture`, so they contribute nothing to what the test asserts.
  remedy: |
    - Seen tests: run the submit inside the capture block, then wait. Either poll `GET /_async_search/{id}` until `is_running` is false before asserting, or use `mockLog.awaitAllExpectationsMatched()`, which already exists (MockLog.java:119).
    - Unseen test: first poll the submitted search to completion, then call `assertAllExpectationsMatched()`.
    - Delete the uncaptured first submit and its polling loop.
  confidence: high
  overlap_hints: [correctness.race]

- severity: Medium
  category: tests.assertion
  file: server/src/test/java/org/elasticsearch/search/SearchServiceTests.java
  line: 501
  title: Unit test asserts only inside the delegate's onFailure, so it passes if the delegate is never called
  evidence: |
                @Override
                public void onFailure(Exception e) {
                    mockLog.assertAllExpectationsMatched();
                }
            };
            Exception e = new Exception(exceptionMessage);
            listener = maybeWrapListenerForStackTrace(listener, shardRequest, threadPool, createClusterService(threadPool));
            listener.onFailure(e);
  impact: The only assertion runs when the wrapped listener forwards the failure. If a regression logs (or doesn't log) and then fails to forward to the delegate, the test still passes with no assertion run. The test also never checks that the delegate actually received the failure, or that its stack trace was cleared after the log was written.
  remedy: |
    - Record the received exception in an `AtomicReference` inside `onFailure`.
    - After `listener.onFailure(e)`, call `mockLog.assertAllExpectationsMatched()` outside the listener.
    - Assert the delegate was invoked with `e` and that `e.getStackTrace().length == 0`.
  confidence: high
  overlap_hints: []

- severity: Medium
  category: tests.coverage
  file: server/src/main/java/org/elasticsearch/search/SearchService.java
  line: 353
  title: The relocated wrap calls in the scroll, QuerySearchRequest (DFS) and rank-feature paths have no test
  evidence: |
            final LegacyReaderContext readerContext = (LegacyReaderContext) findReaderContext(request.contextId(), request);
            final ShardSearchRequest shardSearchRequest = readerContext.getShardSearchRequest(null);
            listener = maybeWrapListenerForStackTrace(listener, shardSearchRequest, threadPool, clusterService);
  impact: In `executeQueryPhase(InternalScrollSearchRequest)`, `executeQueryPhase(QuerySearchRequest)` and `executeRankFeaturePhase`, the change moves `maybeWrapListenerForStackTrace` after `findReaderContext` and now derives the request from the reader context. The new ITs only send default query_then_fetch `_search`/`_msearch`/`_async_search` requests, so only `executeQueryPhase(ShardSearchRequest)` runs. Nothing checks logging or stack-trace stripping on the other three entry points. That includes a failure thrown by `findReaderContext` (for example, a missing context), which now happens before the listener is wrapped.
  remedy: |
    - Add an IT with `search_type=dfs_query_then_fetch` that fails, and assert the seen/unseen log expectations.
    - Add an IT that issues a scroll continuation whose failure reaches the data node.
    - Add a test that sends a QuerySearchRequest or scroll request with an unknown context id, and assert whether that failure keeps its stack trace.
  confidence: medium
  overlap_hints: [correctness.error-path]

- severity: Low
  category: tests.flakiness
  file: server/src/test/java/org/elasticsearch/search/SearchServiceTests.java
  line: 479
  title: Logger level is set to DEBUG and never reset, so it leaks to other tests in the same JVM
  evidence: |
            try (var mockLog = MockLog.capture(SearchService.class)) {
                Configurator.setLevel("org.elasticsearch.search.SearchService", Level.DEBUG);
  impact: Nothing restores the level afterwards. The same applies to the `@BeforeClass setDebugLogLevel()` methods in `SearchErrorTraceIT` (line 57) and `AsyncSearchErrorTraceIT` (line 697), which have no matching `@AfterClass`. Test classes that later share the forked JVM inherit DEBUG logging on SearchService. Their output changes, and any of their log expectations on SearchService depend on which test ran first.
  remedy: Replace the manual calls with `@TestLogging(value = "org.elasticsearch.search.SearchService:DEBUG", reason = "...")` on the test method or class. `LoggingListener` (registered on ESTestCase) restores the previous level afterwards.
  confidence: high
  overlap_hints: []

- severity: Low
  category: tests.assertion
  file: test/framework/src/main/java/org/elasticsearch/test/MockLog.java
  line: 641
  title: PatternAndExceptionSeenEventExpectation throws NPE when an exception has a null message, and only matches the exact class
  evidence: |
                boolean exceptionMatches = event.getThrown() != null
                    && event.getThrown().getClass() == clazz
                    && event.getThrown().getMessage().equals(exceptionMessage);
  impact: The check runs for every SearchService DEBUG/level-matching event while the log is captured. Any logged throwable with a null message throws an NPE. `MockAppender` is built with `ignoreExceptions=false` (MockLog.java:70), so that NPE propagates into the production `logger.debug(...)` call under test and breaks it. The exact `==` class check also means a subclass or wrapped cause silently never matches. The `pattern` string is passed to `super` as `message`, but this class overrides `match` and never uses it.
  remedy: |
    - Compare messages with `Objects.equals(exceptionMessage, event.getThrown().getMessage())`.
    - Collapse the nested ifs into a single condition.
    - Optionally reuse `PatternSeenEventExpectation` together with `ExceptionSeenEventExpectation.innerMatch`.
  confidence: medium
  overlap_hints: [correctness.null-safety]

## Files examined
examined: [CONTRIBUTING.md, docs/changelog/125732.yaml, qa/smoke-test-http/src/internalClusterTest/java/org/elasticsearch/http/SearchErrorTraceIT.java, server/src/main/java/org/elasticsearch/action/search/SearchTransportService.java, server/src/main/java/org/elasticsearch/search/SearchService.java, server/src/test/java/org/elasticsearch/search/SearchServiceSingleNodeTests.java, server/src/test/java/org/elasticsearch/search/SearchServiceTests.java, test/framework/src/main/java/org/elasticsearch/search/ErrorTraceHelper.java, test/framework/src/main/java/org/elasticsearch/test/MockLog.java, x-pack/plugin/async-search/src/internalClusterTest/java/org/elasticsearch/xpack/search/AsyncSearchErrorTraceIT.java]
not_examined: []
