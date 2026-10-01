<!-- elastic__elasticsearch@e38d20c performance-reviewer; verbatim final answer -->
## Performance findings: none

I found no performance regressions in the changed code. Here is what I checked on the hot path:

- **Logging is lazy and only runs on failure.** The new `logger.debug(() -> format(...), e)` call in `SearchService.maybeWrapListenerForStackTrace` (/Users/tufantunc/Desktop/Projects/Personal/aacr-bench/evaluation/work/elastic__elasticsearch@e38d20c/server/src/main/java/org/elasticsearch/search/SearchService.java) sits inside the `delegateResponse` failure callback. That callback is only created when `error_trace` is false, and it only runs when a shard request fails. The message is built only if DEBUG is enabled. On the success path the only extra cost is that the existing `delegateResponse` lambda now also holds references to `request` and `clusterService`, which is negligible.
- **Moving the wrap call adds no work.** In `executeRankFeaturePhase` and `executeQueryPhase(QuerySearchRequest)`, the wrap now runs after `findReaderContext`/`getShardSearchRequest`. Those calls already ran on the same path; only their order changed.
- **The scroll path moves one cheap call earlier.** In `executeQueryPhase(InternalScrollSearchRequest)`, `readerContext.getShardSearchRequest(null)` now runs on the calling thread before `runAsync` instead of inside it. For `LegacyReaderContext` this just returns a stored field (`LegacyReaderContext.java:74-76`), so nothing expensive moves onto the transport thread.
- **The transport service change removes work.** `SearchTransportService` no longer passes `channel.getVersion()`, so it does less, not more.
- **Test code is off the production path.** The new loops in `ErrorTraceHelper` and `MockLog.PatternAndExceptionSeenEventExpectation` only run in tests. They scale with the number of nodes times shards in the test cluster, which is small.

## Files examined
examined: [CONTRIBUTING.md, docs/changelog/125732.yaml, qa/smoke-test-http/src/internalClusterTest/java/org/elasticsearch/http/SearchErrorTraceIT.java, server/src/main/java/org/elasticsearch/action/search/SearchTransportService.java, server/src/main/java/org/elasticsearch/search/SearchService.java, server/src/test/java/org/elasticsearch/search/SearchServiceSingleNodeTests.java, server/src/test/java/org/elasticsearch/search/SearchServiceTests.java, test/framework/src/main/java/org/elasticsearch/search/ErrorTraceHelper.java, test/framework/src/main/java/org/elasticsearch/test/MockLog.java, x-pack/plugin/async-search/src/internalClusterTest/java/org/elasticsearch/xpack/search/AsyncSearchErrorTraceIT.java]
not_examined: []
