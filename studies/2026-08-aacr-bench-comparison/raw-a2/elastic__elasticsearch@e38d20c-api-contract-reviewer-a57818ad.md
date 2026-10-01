<!-- elastic__elasticsearch@e38d20c api-contract-reviewer; verbatim final answer -->
- severity: Low
  category: api-contract.breaking
  file: server/src/main/java/org/elasticsearch/search/SearchService.java
  line: 865
  title: The error_trace version check for scroll query-phase continuations now uses the transport version of the original request, not the version of the node sending the scroll request
  evidence: |
    final LegacyReaderContext readerContext = (LegacyReaderContext) findReaderContext(request.contextId(), request);
    final ShardSearchRequest shardSearchRequest = readerContext.getShardSearchRequest(null);
    listener = maybeWrapListenerForStackTrace(listener, shardSearchRequest, threadPool, clusterService);
    ...
    if (request.getChannelVersion().onOrAfter(ERROR_TRACE_IN_TRANSPORT_HEADER) && threadPool.getThreadContext() != null) {
        header = Boolean.parseBoolean(threadPool.getThreadContext().getHeaderOrDefault("error_trace", "false"));
    }
  evidence_refs: [server/src/main/java/org/elasticsearch/search/internal/LegacyReaderContext.java:74, server/src/main/java/org/elasticsearch/search/SearchService.java:1123, server/src/main/java/org/elasticsearch/search/internal/ShardSearchRequest.java:330, server/src/main/java/org/elasticsearch/action/search/SearchScrollAsyncAction.java:140, server/src/main/java/org/elasticsearch/action/search/SearchTransportService.java:468]
  impact: Before this change, the `QUERY_SCROLL_ACTION_NAME` handler passed `channel.getVersion()`, the transport version of the node sending this scroll request. Now the check uses the `channelVersion` of the request stored in the `LegacyReaderContext`. `LegacyReaderContext.getShardSearchRequest` ignores its argument and returns that stored request. A scroll id can be continued from any node: `SearchScrollAsyncAction` opens a new connection to the shard's node for each continuation. In a mixed-version cluster, suppose a node at or after `ERROR_TRACE_IN_TRANSPORT_HEADER` created the scroll context and an older node sends the continuation. The older node never sends an `error_trace` header, so the header defaults to "false" and the data node strips stack traces. Older nodes expect the earlier behaviour, where traces are always kept. The reverse case also flips: a newer node continuing a context created by an older one keeps traces even without `error_trace=true`. The impact is limited to scroll, mixed-version clusters and diagnostics only. Nothing fails to deserialize. The `QuerySearchRequest` path keeps the same semantics: a non-legacy `ReaderContext` returns the request that just arrived over the wire, whose `channelVersion` is the minimum of the sender's stored value and the incoming stream version. The DFS+scroll case goes through the same coordinator.
  remedy: For `InternalScrollSearchRequest`, keep passing the version of the incoming channel to the gate, for example `TransportVersion.min(channel.getVersion(), shardSearchRequest.getChannelVersion())` passed explicitly, or an overload that takes the version separately from the `ShardSearchRequest` used for log context. Alternatively, document that the scroll gate deliberately follows the version of the node that created the context.
  confidence: medium
  overlap_hints: [correctness.mixed-version]

Other API-contract checks:
- **Callers of the changed signatures:** The two public `SearchService.executeQueryPhase` overloads dropped the `TransportVersion` parameter. `git grep` across all `*.java` (server, x-pack, modules, plugins) finds only the two updated callers in `SearchTransportService` (lines 456 and 468) and the test at `SearchServiceSingleNodeTests.java:2630`. `maybeWrapListenerForStackTrace` is package-private and all its callers are updated.
- **Wire and REST representation:** No serialization or REST response changes. The change only adds a debug log.

## Files examined
examined: [CONTRIBUTING.md, docs/changelog/125732.yaml, qa/smoke-test-http/src/internalClusterTest/java/org/elasticsearch/http/SearchErrorTraceIT.java, server/src/main/java/org/elasticsearch/action/search/SearchTransportService.java, server/src/main/java/org/elasticsearch/search/SearchService.java, server/src/test/java/org/elasticsearch/search/SearchServiceSingleNodeTests.java, server/src/test/java/org/elasticsearch/search/SearchServiceTests.java, test/framework/src/main/java/org/elasticsearch/search/ErrorTraceHelper.java, test/framework/src/main/java/org/elasticsearch/test/MockLog.java]
not_examined:
  - file: x-pack/plugin/async-search/src/internalClusterTest/java/org/elasticsearch/xpack/search/AsyncSearchErrorTraceIT.java
    reason: I only read the start of its diff (imports and setup) because the output was truncated; the test methods were not read. It is test-only and outside the API contract.
