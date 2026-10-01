<!-- elastic__elasticsearch@a6a4623 dry-reviewer; verbatim final answer -->
## DRY findings

- severity: Low
  category: dry.missing-abstraction
  file: server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/PlainHighlighter.java
  line: 126
  title: The "query offset is unset or above the index limit" check is repeated in CustomUnifiedHighlighter, and the new value type could own it
  evidence: |
    if ((queryMaxAnalyzedOffset == null || queryMaxAnalyzedOffset.getNotNull() > maxAnalyzedOffset)
        && (textLength > maxAnalyzedOffset)) {
  evidence_refs:
    - server/src/main/java/org/elasticsearch/lucene/search/uhighlight/CustomUnifiedHighlighter.java:128
  impact: The same condition appears in both places: `(queryMaxAnalyzedOffset == null || queryMaxAnalyzedOffset.getNotNull() > maxAnalyzedOffset)`. This change had to rewrite both copies the same way when the type moved from `Integer` to `QueryMaxAnalyzedOffset`. Each copy compares the resolved value against an index limit passed in separately. The same index limit was already given to `QueryMaxAnalyzedOffset.create(..., maxAnalyzedOffset)` in DefaultHighlighter.java:125-128 and PlainHighlighter.java:111-114. Future changes to the `-1`/index-default rules will need to update both call sites again.
  remedy: Keep `indexMaxAnalyzedOffset` in `QueryMaxAnalyzedOffset`, or pass it in. Then add one method to that class, such as `static boolean exceedsIndexLimit(QueryMaxAnalyzedOffset q, int indexMax)`, or make the check null-safe some other way. Call it from PlainHighlighter.java:126 and CustomUnifiedHighlighter.java:128 so the rule is written once.
  confidence: medium
  overlap_hints: [craft.abstraction]

- severity: Low
  category: dry.duplication
  file: server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/PlainHighlighter.java
  line: 249
  title: PlainHighlighter.wrapAnalyzer is the same as DefaultHighlighter.wrapAnalyzer, and this change edited both the same way
  evidence: |
    private static Analyzer wrapAnalyzer(Analyzer analyzer, QueryMaxAnalyzedOffset maxAnalyzedOffset) {
        if (maxAnalyzedOffset != null) {
            return new LimitTokenOffsetAnalyzer(analyzer, maxAnalyzedOffset.getNotNull());
        }
        return analyzer;
    }
  evidence_refs:
    - server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/DefaultHighlighter.java:193
  impact: The copy at DefaultHighlighter.java:193-198 has the same body, `if (maxAnalyzedOffset != null) analyzer = new LimitTokenOffsetAnalyzer(analyzer, maxAnalyzedOffset.getNotNull());`. The duplication predates this change, but the change edited both copies identically: new parameter type and `.getNotNull()` unwrap. Any future change to how the limit is applied will need the same double edit.
  remedy: Keep one static helper. Good homes are `LimitTokenOffsetAnalyzer` (server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/LimitTokenOffsetAnalyzer.java:32), e.g. `static Analyzer wrap(Analyzer, QueryMaxAnalyzedOffset)`, or `QueryMaxAnalyzedOffset`. Delete PlainHighlighter's private copy. DefaultHighlighter's overridable `protected wrapAnalyzer` can delegate to the helper, because AnnotatedTextHighlighter overrides it.
  confidence: high
  overlap_hints: [craft.code-judo]

## Files examined
examined: [plugins/mapper-annotated-text/src/main/java/org/elasticsearch/index/mapper/annotatedtext/AnnotatedTextHighlighter.java, plugins/mapper-annotated-text/src/test/java/org/elasticsearch/index/mapper/annotatedtext/AnnotatedTextHighlighterTests.java, rest-api-spec/src/yamlRestTest/resources/rest-api-spec/test/search.highlight/30_max_analyzed_offset.yml, server/src/internalClusterTest/java/org/elasticsearch/search/fetch/subphase/highlight/HighlighterSearchIT.java, server/src/main/java/org/elasticsearch/lucene/search/uhighlight/CustomFieldHighlighter.java, server/src/main/java/org/elasticsearch/lucene/search/uhighlight/CustomUnifiedHighlighter.java, server/src/main/java/org/elasticsearch/lucene/search/uhighlight/QueryMaxAnalyzedOffset.java, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/AbstractHighlighterBuilder.java, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/DefaultHighlighter.java, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/PlainHighlighter.java, server/src/test/java/org/elasticsearch/lucene/search/uhighlight/CustomUnifiedHighlighterTests.java, server/src/test/java/org/elasticsearch/search/fetch/subphase/highlight/HighlightBuilderTests.java]
not_examined: []
