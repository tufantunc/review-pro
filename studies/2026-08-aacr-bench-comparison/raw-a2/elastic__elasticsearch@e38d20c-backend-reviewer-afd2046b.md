<!-- elastic__elasticsearch@e38d20c backend-reviewer; verbatim final answer -->
## Backend findings

- severity: Low
  category: backend.error-handling
  file: server/src/main/java/org/elasticsearch/search/SearchService.java
  line: 865
  title: The scroll query phase checks the wrong channel version when deciding whether to strip stack traces
  evidence: |
    final LegacyReaderContext readerContext = (LegacyReaderContext) findReaderContext(request.contextId(), request);
    final ShardSearchRequest shardSearchRequest = readerContext.getShardSearchRequest(null);
    listener = maybeWrapListenerForStackTrace(listener, shardSearchRequest, threadPool, clusterService);
  evidence_refs: [server/src/main/java/org/elasticsearch/search/internal/LegacyReaderContext.java:74, server/src/main/java/org/elasticsearch/search/internal/ShardSearchRequest.java:330, server/src/main/java/org/elasticsearch/action/search/SearchTransportService.java:468]
  impact: |
    Before this change, the decision used the version of the channel that carried the scroll request (`channel.getVersion()`). `LegacyReaderContext.getShardSearchRequest(null)` returns the request saved during the initial query phase, so `request.getChannelVersion()` is now the version of the node that started the search. A later scroll can come from a different coordinating node, or from the same node after it has been upgraded or downgraded during a rolling upgrade.
    The `error_trace` header, however, is still read from the scroll request's own thread context. Suppose the initial search came from a node that supports the header and the scroll comes from an older node that doesn't send it. The `onOrAfter(ERROR_TRACE_IN_TRANSPORT_HEADER)` check passes, the missing header falls back to `"false"`, and the stack traces get stripped. That old node always expected stack traces, and the method's own javadoc says the default is `true` for older nodes.
    The reverse also happens: a newer scroll coordinator's `error_trace=false` is ignored. The effect is limited to mixed-version clusters and to whether stack traces are present, but the change silently drops a version check that used to be correct.
  remedy: |
    Keep using the version of the incoming scroll channel. You can keep a `TransportVersion` parameter or overload on `executeQueryPhase(InternalScrollSearchRequest, ...)` and on `maybeWrapListenerForStackTrace`, and pass the `ShardSearchRequest` separately just for the log message (shardId). Or read the version from the deserialized `InternalScrollSearchRequest` instead of from the request stored in the reader context.
  confidence: medium
  overlap_hints: [api-contract.back-compat, correctness.error-path]

Notes from the requested checks (none of these is a finding):
- **Wrapping moved after `findReaderContext`/`getShardSearchRequest`:** this changes nothing for synchronous throws. Exceptions such as `SearchContextMissingException`, the `markAsUsed` keep-alive failures and `requireNonNull` in `ReaderContext.getShardSearchRequest` are thrown before any listener is called. They already went straight to the transport handler without being stripped before this change, and they still do; they just aren't logged now either.
- **Log level and cost:** DEBUG is a reasonable level for this message. The supplier is lazy, so `clusterService.localNode()` and the formatting only run when DEBUG is enabled, and only inside a listener callback on a started node.

## Files examined
examined: [CONTRIBUTING.md, docs/changelog/125732.yaml, qa/smoke-test-http/src/internalClusterTest/java/org/elasticsearch/http/SearchErrorTraceIT.java, server/src/main/java/org/elasticsearch/action/search/SearchTransportService.java, server/src/main/java/org/elasticsearch/search/SearchService.java, server/src/test/java/org/elasticsearch/search/SearchServiceSingleNodeTests.java, server/src/test/java/org/elasticsearch/search/SearchServiceTests.java, test/framework/src/main/java/org/elasticsearch/search/ErrorTraceHelper.java, test/framework/src/main/java/org/elasticsearch/test/MockLog.java]
not_examined:
  - file: x-pack/plugin/async-search/src/internalClusterTest/java/org/elasticsearch/xpack/search/AsyncSearchErrorTraceIT.java
    reason: Only read the first part of the diff (cut off at head -400); the test-only remainder was not read.
