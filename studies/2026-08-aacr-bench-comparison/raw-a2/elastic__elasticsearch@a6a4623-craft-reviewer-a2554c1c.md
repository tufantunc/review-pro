<!-- elastic__elasticsearch@a6a4623 craft-reviewer; verbatim final answer -->
## Craft findings

- severity: Medium
  category: craft.code-judo
  file: server/src/main/java/org/elasticsearch/lucene/search/uhighlight/QueryMaxAnalyzedOffset.java
  line: 12
  title: The new QueryMaxAnalyzedOffset wrapper can itself be null, so it adds no type guarantee and forces signature changes across 5 files, including a protected extension point
  evidence: |
    public static QueryMaxAnalyzedOffset create(final Integer queryMaxAnalyzedOffset, final int indexMaxAnalyzedOffset) {
        if (queryMaxAnalyzedOffset == null) {
            return null;
        }
        return new QueryMaxAnalyzedOffset(queryMaxAnalyzedOffset < 0 ? indexMaxAnalyzedOffset : queryMaxAnalyzedOffset);
    }

    public int getNotNull() {
        return queryMaxAnalyzedOffset;
    }
    ---
    // CustomUnifiedHighlighter.java:128
    if ((queryMaxAnalyzedOffset == null || queryMaxAnalyzedOffset.getNotNull() > maxAnalyzedOffset)
    // PlainHighlighter.java:126
    if ((queryMaxAnalyzedOffset == null || queryMaxAnalyzedOffset.getNotNull() > maxAnalyzedOffset)
    // DefaultHighlighter.java:193 (protected, overridden by AnnotatedTextHighlighter.java:56)
    protected Analyzer wrapAnalyzer(Analyzer analyzer, QueryMaxAnalyzedOffset maxAnalyzedOffset) {
  evidence_refs: [server/src/main/java/org/elasticsearch/lucene/search/uhighlight/CustomUnifiedHighlighter.java:128, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/PlainHighlighter.java:126, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/DefaultHighlighter.java:193, server/src/main/java/org/elasticsearch/lucene/search/uhighlight/CustomFieldHighlighter.java:116, plugins/mapper-annotated-text/src/main/java/org/elasticsearch/index/mapper/annotatedtext/AnnotatedTextHighlighter.java:56]
  impact: The feature only needs one rule at one point: -1 means "use the index setting". This change instead adds a new public type and threads it through CustomUnifiedHighlighter, CustomFieldHighlighter, DefaultHighlighter, PlainHighlighter and the plugin override of the protected `wrapAnalyzer` hook. Because `create` returns null, every consumer still does the same `!= null` check it did with `Integer`, and then also unwraps with the oddly named `getNotNull()`. The class holds no behaviour: the "query limit exceeds the index limit" check is still copied in PlainHighlighter and CustomUnifiedHighlighter. The constructor comment ("If we have a negative value, grab value for the actual maximum from the index") describes logic that actually sits in `create`, so it is misleading where it stands. Any third-party subclass of DefaultHighlighter that overrides `wrapAnalyzer(Analyzer, Integer)` breaks for no functional gain.
  remedy: Delete the class. Resolve the sentinel once where the options are read, for example a static `Integer resolveQueryMaxAnalyzedOffset(Integer query, int indexMax)` next to `maxAnalyzedOffset` in the highlight package, called in DefaultHighlighter and PlainHighlighter. Keep `Integer` in the CustomUnifiedHighlighter, CustomFieldHighlighter and `wrapAnalyzer` signatures, which removes the churn in 5 files and the plugin. If a type is really wanted, make it pay for itself: a final class/record that owns `exceedsIndexLimit(int indexMax)`, so the duplicated predicate goes away, with a normal accessor (`value()`) and the stray constructor comment moved or removed.
  confidence: high
  overlap_hints: [api-contract.breaking-signature, dry.duplication]

- severity: Low
  category: craft.boundary
  file: server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/AbstractHighlighterBuilder.java
  line: 569
  title: The -1 sentinel is an unnamed magic value, and the validator, javadoc and resolver describe it differently
  evidence: |
    * "maxAnalyzedOffset" might be non-negative int, null (unknown), or a negative int (defaulting to index analyzed offset).
    */
    public HB maxAnalyzedOffset(Integer maxAnalyzedOffset) {
        if (maxAnalyzedOffset != null && maxAnalyzedOffset < -1) {
            throw new IllegalArgumentException("[" + MAX_ANALYZED_OFFSET_FIELD + "] must be an integer >= -1");
    ---
    // QueryMaxAnalyzedOffset.java:24
    return new QueryMaxAnalyzedOffset(queryMaxAnalyzedOffset < 0 ? indexMaxAnalyzedOffset : queryMaxAnalyzedOffset);
  evidence_refs: [server/src/main/java/org/elasticsearch/lucene/search/uhighlight/QueryMaxAnalyzedOffset.java:24]
  impact: The meaning of the value is spread across three places that don't agree. The javadoc says any negative int means "use the index default". The validator allows only -1. The resolver treats `< 0` as the sentinel. The javadoc also calls null "unknown", when it actually means "no query-level limit". There is no named constant, so the next reader has to rediscover the real rule by reading all three.
  remedy: Add one named constant (for example `USE_INDEX_MAX_ANALYZED_OFFSET = -1`) in the highlight builder. Validate against it, resolve with `== USE_INDEX_MAX_ANALYZED_OFFSET` instead of `< 0`, and rewrite the javadoc to describe exactly three states: null means no query limit, -1 means use the index setting, and a positive value is used as the limit.
  confidence: high
  overlap_hints: [api-contract.schema-drift, correctness.logic]

## Files examined
examined: [plugins/mapper-annotated-text/src/main/java/org/elasticsearch/index/mapper/annotatedtext/AnnotatedTextHighlighter.java, plugins/mapper-annotated-text/src/test/java/org/elasticsearch/index/mapper/annotatedtext/AnnotatedTextHighlighterTests.java, rest-api-spec/src/yamlRestTest/resources/rest-api-spec/test/search.highlight/30_max_analyzed_offset.yml, server/src/internalClusterTest/java/org/elasticsearch/search/fetch/subphase/highlight/HighlighterSearchIT.java, server/src/main/java/org/elasticsearch/lucene/search/uhighlight/CustomFieldHighlighter.java, server/src/main/java/org/elasticsearch/lucene/search/uhighlight/CustomUnifiedHighlighter.java, server/src/main/java/org/elasticsearch/lucene/search/uhighlight/QueryMaxAnalyzedOffset.java, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/AbstractHighlighterBuilder.java, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/DefaultHighlighter.java, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/PlainHighlighter.java, server/src/test/java/org/elasticsearch/lucene/search/uhighlight/CustomUnifiedHighlighterTests.java, server/src/test/java/org/elasticsearch/search/fetch/subphase/highlight/HighlightBuilderTests.java]
not_examined: []
