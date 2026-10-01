<!-- elastic__elasticsearch@a6a4623 backend-reviewer; verbatim final answer -->
- severity: Medium
  category: backend.validation
  file: server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/AbstractHighlighterBuilder.java
  line: 568
  title: Validation now accepts `max_analyzed_offset: 0`, not just the new `-1` sentinel
  evidence: |
    -        if (maxAnalyzedOffset != null && maxAnalyzedOffset <= 0) {
    -            throw new IllegalArgumentException("[" + MAX_ANALYZED_OFFSET_FIELD + "] must be a positive integer");
    +        if (maxAnalyzedOffset != null && maxAnalyzedOffset < -1) {
    +            throw new IllegalArgumentException("[" + MAX_ANALYZED_OFFSET_FIELD + "] must be an integer >= -1");
  impact: The stated goal is to add `-1` as a sentinel. The bound change also lets `0` through, and before this change `0` was rejected with a 400. The parser (`parser.declareInt(HB::maxAnalyzedOffset, ...)` at line 670) and transport deserialization (`maxAnalyzedOffset(in.readOptionalInt())` at line 168) both go through this setter, so REST and inter-node requests now accept `0`. `QueryMaxAnalyzedOffset.create` passes `0` through unchanged, since only negative values map to the index setting. Callers then wrap the analyzer with `new LimitTokenOffsetAnalyzer(analyzer, 0)`, and the unified highlighter wraps offsets with `new LimitedOffsetsEnum(off, 0)`. In the length guard (`queryMaxAnalyzedOffset.getNotNull() > maxAnalyzedOffset`), `0 > max` is false, so the "field too long" exception is skipped. The result: a request that used to get a clear 400 now returns 200 with empty or missing highlights and no error. The javadoc also says "a negative int (defaulting to index analyzed offset)", but the setter rejects anything below -1, so the documented contract and the enforced one disagree. `HighlightBuilderTests` still uses `randomIntBetween(-100, 0)` and expects every value to fail, which shows the widening was not intended. That test now fails whenever the random value is -1 or 0.
  remedy: Accept exactly the sentinel plus positive values, for example `if (maxAnalyzedOffset != null && maxAnalyzedOffset != -1 && maxAnalyzedOffset <= 0) throw ... "must be a positive integer or -1"`. Update the javadoc to say that only `-1` means "use `index.highlight.max_analyzed_offset`". Consider a named constant (for example `USE_INDEX_MAX_ANALYZED_OFFSET = -1`) instead of the bare `< 0` check in `QueryMaxAnalyzedOffset.create`. Change the test range in `HighlightBuilderTests` to exclude -1 and 0, or add a separate test that `0` is rejected.
  confidence: high
  evidence_refs: [server/src/main/java/org/elasticsearch/lucene/search/uhighlight/QueryMaxAnalyzedOffset.java:24, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/PlainHighlighter.java:126, server/src/main/java/org/elasticsearch/lucene/search/uhighlight/CustomUnifiedHighlighter.java:128, server/src/test/java/org/elasticsearch/search/fetch/subphase/highlight/HighlightBuilderTests.java:580]
  overlap_hints: [api-contract.breaking, tests.flaky, correctness.logic]

## Files examined
examined: [plugins/mapper-annotated-text/src/main/java/org/elasticsearch/index/mapper/annotatedtext/AnnotatedTextHighlighter.java, rest-api-spec/src/yamlRestTest/resources/rest-api-spec/test/search.highlight/30_max_analyzed_offset.yml, server/src/main/java/org/elasticsearch/lucene/search/uhighlight/CustomFieldHighlighter.java, server/src/main/java/org/elasticsearch/lucene/search/uhighlight/CustomUnifiedHighlighter.java, server/src/main/java/org/elasticsearch/lucene/search/uhighlight/QueryMaxAnalyzedOffset.java, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/AbstractHighlighterBuilder.java, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/DefaultHighlighter.java, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/PlainHighlighter.java, server/src/test/java/org/elasticsearch/search/fetch/subphase/highlight/HighlightBuilderTests.java]
not_examined:
  - file: plugins/mapper-annotated-text/src/test/java/org/elasticsearch/index/mapper/annotatedtext/AnnotatedTextHighlighterTests.java
    reason: test code; only grep-filtered added lines were seen, not the full diff
  - file: server/src/internalClusterTest/java/org/elasticsearch/search/fetch/subphase/highlight/HighlighterSearchIT.java
    reason: test code; only grep-filtered added lines were seen, not the full diff
  - file: server/src/test/java/org/elasticsearch/lucene/search/uhighlight/CustomUnifiedHighlighterTests.java
    reason: test code; only grep-filtered added lines were seen, not the full diff
