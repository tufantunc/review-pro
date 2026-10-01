<!-- elastic__elasticsearch@a6a4623 correctness-reviewer; verbatim final answer -->
- severity: Medium
  category: correctness.logic
  file: server/src/test/java/org/elasticsearch/search/fetch/subphase/highlight/HighlightBuilderTests.java
  line: 580
  title: testInvalidMaxAnalyzedOffset still picks from [-100, 0], but -1 and 0 are now valid, so the test fails at random
  evidence: |
    XContentParseException e = expectParseThrows(
        XContentParseException.class,
        "{ \"max_analyzed_offset\" : " + randomIntBetween(-100, 0) + "}"
    );
    ...
    assertThat(e.getCause().getMessage(), containsString("[max_analyzed_offset] must be an integer >= -1"));
  evidence_refs: [server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/AbstractHighlighterBuilder.java:568]
  impact: The validator is now `maxAnalyzedOffset < -1` (AbstractHighlighterBuilder.java:568), so the values -1 and 0 parse without error. When the random seed picks either one (2 of the 101 possible values), `expectParseThrows` sees no exception and the test fails. The change updated the expected message but left the range alone.
  remedy: Use `randomIntBetween(-100, -2)`. Separately, add a positive test that -1 parses.
  confidence: high
  overlap_hints: [tests.flaky]

- severity: Medium
  category: correctness.side-effect
  file: rest-api-spec/src/yamlRestTest/resources/rest-api-spec/test/search.highlight/30_max_analyzed_offset.yml
  line: 133
  title: The error-message assertion changed, but the test is still gated only on gte_v7.12.0, so it fails in the mixed-cluster BWC suite
  evidence: |
    - requires:
        cluster_features: ["gte_v7.12.0"]
    ...
    - match: { error.caused_by.reason: "[max_analyzed_offset] must be an integer >= -1" }
  evidence_refs: [qa/mixed-cluster/build.gradle:29-31, qa/mixed-cluster/build.gradle:35-40]
  impact: qa/mixed-cluster runs every core yaml test (`includeCore '*'`), and its node selector sends REST requests to the old-version nodes. An old node parses `max_analyzed_offset: -10` and rejects it with "[max_analyzed_offset] must be a positive integer". That fails this `match` every time, so the BWC CI run breaks deterministically.
  remedy: Add a cluster feature for the new semantics and gate the test on it, or add the test to the mixed-cluster excludeList / skipTest. Another option is to relax the reason match to something both versions produce.
  confidence: high
  overlap_hints: [api-contract.back-compat, tests.coverage]

- severity: Medium
  category: correctness.side-effect
  file: server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/AbstractHighlighterBuilder.java
  line: 568
  title: A -1 sent over transport to an older node fails when the old node deserializes it (no TransportVersion gate)
  evidence: |
    // readFrom (line 168)
    maxAnalyzedOffset(in.readOptionalInt());
    // writeTo (line 212)
    out.writeOptionalInt(maxAnalyzedOffset);
    // new validation
    if (maxAnalyzedOffset != null && maxAnalyzedOffset < -1) {
  impact: During a rolling upgrade, a new coordinating node accepts `max_analyzed_offset: -1` and writes it unchanged into the shard request's SearchSourceBuilder. An old data node's `readFrom` calls `maxAnalyzedOffset(-1)`, which on the old code throws IllegalArgumentException("must be a positive integer"). Every shard on an old node fails for that request, so the result is partial or failed, with a confusing deserialization error instead of a clean 400. Requests that do not use -1 are unaffected.
  remedy: Gate on a new TransportVersion. When writing to an older node, either reject -1 up front or resolve/strip it (e.g. write null, or fail with a clear message). Alternatively, reject -1 at the coordinator until the whole cluster supports it.
  confidence: medium
  overlap_hints: [api-contract.back-compat]

- severity: Low
  category: correctness.logic
  file: server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/AbstractHighlighterBuilder.java
  line: 568
  title: Relaxing the bound from `<= 0` to `< -1` also makes 0 valid, which is a separate, undocumented behavior change
  evidence: |
    -        if (maxAnalyzedOffset != null && maxAnalyzedOffset <= 0) {
    +        if (maxAnalyzedOffset != null && maxAnalyzedOffset < -1) {
  impact: The feature only needs the sentinel -1. `max_analyzed_offset: 0` used to be rejected with a 400. It is now accepted and becomes `new LimitTokenOffsetAnalyzer(analyzer, 0)`, which (with `QueryMaxAnalyzedOffset.create` leaving 0 unchanged) analyzes only a token starting at offset 0. Clients that relied on 0 being rejected now silently get near-empty highlights. The docs at highlighting.asciidoc:261-270 still describe a positive value.
  remedy: Accept exactly -1 or positive values (`maxAnalyzedOffset != null && maxAnalyzedOffset != -1 && maxAnalyzedOffset <= 0`), and update the message and docs to match.
  confidence: medium
  overlap_hints: [api-contract.validation]

## Files examined
examined: [plugins/mapper-annotated-text/src/main/java/org/elasticsearch/index/mapper/annotatedtext/AnnotatedTextHighlighter.java, plugins/mapper-annotated-text/src/test/java/org/elasticsearch/index/mapper/annotatedtext/AnnotatedTextHighlighterTests.java, rest-api-spec/src/yamlRestTest/resources/rest-api-spec/test/search.highlight/30_max_analyzed_offset.yml, server/src/internalClusterTest/java/org/elasticsearch/search/fetch/subphase/highlight/HighlighterSearchIT.java, server/src/main/java/org/elasticsearch/lucene/search/uhighlight/CustomFieldHighlighter.java, server/src/main/java/org/elasticsearch/lucene/search/uhighlight/CustomUnifiedHighlighter.java, server/src/main/java/org/elasticsearch/lucene/search/uhighlight/QueryMaxAnalyzedOffset.java, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/AbstractHighlighterBuilder.java, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/DefaultHighlighter.java, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/PlainHighlighter.java, server/src/test/java/org/elasticsearch/lucene/search/uhighlight/CustomUnifiedHighlighterTests.java, server/src/test/java/org/elasticsearch/search/fetch/subphase/highlight/HighlightBuilderTests.java]
not_examined: []
