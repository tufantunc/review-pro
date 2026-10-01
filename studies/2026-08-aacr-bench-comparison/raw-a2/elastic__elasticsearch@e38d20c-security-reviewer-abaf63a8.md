<!-- elastic__elasticsearch@e38d20c security-reviewer; verbatim final answer -->
I found no security issues in this change.

## Security findings: none

Here is how I settled the two concerns you raised:

- **Data in DEBUG logs:** The new `logger.debug` call in `maybeWrapListenerForStackTrace` (`server/src/main/java/org/elasticsearch/search/SearchService.java:557`) logs the node id, the shard id and the exception. The exception message is the same one already sent back to the coordinating node and shown to the client. The coordinating node also already logs these failures at DEBUG, sometimes with the full request (`server/src/main/java/org/elasticsearch/action/search/AbstractSearchAsyncAction.java:338`, `:380`, `:405`). DEBUG is off by default, and only an operator can turn it on. So nothing new is exposed and no trust boundary is crossed.
- **Mixed-version clusters and the `error_trace` gate:** For the query-by-id and scroll paths, the version check now reads the version stored with the original shard request instead of the current connection's version. In a mixed-version cluster that can make a data node send a stack trace to the coordinating node when it would previously have cleared it. That traffic stays between nodes. What the client sees is decided separately:
  - `RestResponse` only renders stack traces when the client passes `error_trace=true` (`server/src/main/java/org/elasticsearch/rest/RestResponse.java:147`).
  - `ElasticsearchException` skips them by default (`REST_EXCEPTION_SKIP_STACK_TRACE_DEFAULT = true`, `server/src/main/java/org/elasticsearch/ElasticsearchException.java:101` and `:446`).
  
  So no stack trace reaches a client that didn't ask for one.

The remaining changes are tests, the test framework (`ErrorTraceHelper`, `MockLog.PatternAndExceptionSeenEventExpectation`) and docs. They add no production attack surface.

## Files examined
examined: [CONTRIBUTING.md, docs/changelog/125732.yaml, qa/smoke-test-http/src/internalClusterTest/java/org/elasticsearch/http/SearchErrorTraceIT.java, server/src/main/java/org/elasticsearch/action/search/SearchTransportService.java, server/src/main/java/org/elasticsearch/search/SearchService.java, server/src/test/java/org/elasticsearch/search/SearchServiceSingleNodeTests.java, server/src/test/java/org/elasticsearch/search/SearchServiceTests.java, test/framework/src/main/java/org/elasticsearch/search/ErrorTraceHelper.java, test/framework/src/main/java/org/elasticsearch/test/MockLog.java]
not_examined:
  - file: x-pack/plugin/async-search/src/internalClusterTest/java/org/elasticsearch/xpack/search/AsyncSearchErrorTraceIT.java
    reason: I only read the start of its diff (imports and setup) before the output was cut off; it is test-only code.
