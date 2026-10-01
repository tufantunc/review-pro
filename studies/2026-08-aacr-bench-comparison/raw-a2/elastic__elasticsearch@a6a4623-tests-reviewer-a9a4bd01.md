<!-- elastic__elasticsearch@a6a4623 tests-reviewer; verbatim final answer -->
## Tests findings

- severity: High
  category: tests.flakiness
  file: server/src/test/java/org/elasticsearch/search/fetch/subphase/highlight/HighlightBuilderTests.java
  line: 580
  title: testInvalidMaxAnalyzedOffset draws values that are now valid, so the test sometimes fails
  evidence: |
    XContentParseException e = expectParseThrows(
        XContentParseException.class,
        "{ \"max_analyzed_offset\" : " + randomIntBetween(-100, 0) + "}"
    );
    ...
    assertThat(e.getCause().getMessage(), containsString("[max_analyzed_offset] must be an integer >= -1"));
    // production (AbstractHighlighterBuilder.java):
    if (maxAnalyzedOffset != null && maxAnalyzedOffset < -1) {
  impact: The new check only rejects values below -1. The random range [-100, 0] still includes -1 and 0, which now parse without error, so `expectParseThrows` fails. That happens on about 2 in 101 seeds. The diff changed the expected message but kept the old range. The result is a seed-dependent CI failure.
  remedy: Change the range to `randomIntBetween(-100, -2)`, or use `randomIntBetween(Integer.MIN_VALUE, -2)`. Add a positive test that `max_analyzed_offset: -1` parses and survives the builder's serialization round-trip with the value -1.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: High
  category: tests.assertion
  file: rest-api-spec/src/yamlRestTest/resources/rest-api-spec/test/search.highlight/30_max_analyzed_offset.yml
  line: 133
  title: Changed error message is still gated on gte_v7.12.0, which breaks mixed-cluster and REST-compat runs
  evidence: |
    "Plain highlighter with max_analyzed_offset < -1 should FAIL":
      - requires:
          cluster_features: ["gte_v7.12.0"]
    ...
      - match: { error.caused_by.reason: "[max_analyzed_offset] must be an integer >= -1" }
  impact: `qa/mixed-cluster/build.gradle:30` runs every core yaml test (`includeCore '*'`). When the request reaches an older node, it still returns "[max_analyzed_offset] must be a positive integer", so the match fails. The reverse also happens: the previous version's yaml, run by yamlRestCompatTest against the new node, expects the old message. `rest-api-spec/build.gradle` has no `skipTest` or `replaceValueInMatch` for this test.
  remedy: Gate the test on a new cluster feature (or version) that marks this change. Add `task.replaceValueInMatch("error.caused_by.reason", "[max_analyzed_offset] must be an integer >= -1", "search.highlight/30_max_analyzed_offset/Plain highlighter with max_analyzed_offset < 0 should FAIL")` to the compat task in rest-api-spec/build.gradle, or a `skipTest` for it.
  confidence: medium
  evidence_refs: [qa/mixed-cluster/build.gradle:30, rest-api-spec/build.gradle:58]
  overlap_hints: [api-contract.backcompat]

- severity: Medium
  category: tests.coverage
  file: server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/PlainHighlighter.java
  line: 126
  title: No test covers -1 on the plain highlighter, or on the unified highlighter's no-offsets (ANALYSIS) path
  evidence: |
    QueryMaxAnalyzedOffset queryMaxAnalyzedOffset = QueryMaxAnalyzedOffset.create(
        fieldContext.field.fieldOptions().maxAnalyzedOffset(),
        maxAnalyzedOffset
    );
    ...
    if ((queryMaxAnalyzedOffset == null || queryMaxAnalyzedOffset.getNotNull() > maxAnalyzedOffset)
        && (textLength > maxAnalyzedOffset)) {
  impact: The feature works because `getNotNull() == maxAnalyzedOffset` skips the "too long" exception and the analyzer gets truncated. No test sends -1 through PlainHighlighter. The only end-to-end test, `HighlighterSearchIT.testMaxQueryOffsetDefault`, uses `type1PostingsffsetsMapping()` (`index_options: offsets`), so it takes the postings path and never reaches the `OffsetSource.ANALYSIS` exception check in `CustomUnifiedHighlighter`. That leaves the main user-facing case, a long field without offsets plus `-1`, untested at the REST/IT level for both highlighters. If `>` were changed to `>=`, or `create` stopped mapping -1, nothing would fail except the annotated-text unit test.
  remedy: In 30_max_analyzed_offset.yml, gated on the new feature, add "Plain highlighter on a field WITHOUT OFFSETS ... with max_analyzed_offset=-1 should SUCCEED" and a matching unified case. Both should use field1 with index setting 30 and expect `"The quick brown <em>fox</em> went to the forest and saw another fox."`, which is the same truncated result as the existing `=20` cases. Alternatively, add a HighlighterSearchIT case on a field without offsets, run for both the "plain" and "unified" highlighter types.
  confidence: high
  evidence_refs: [server/src/internalClusterTest/java/org/elasticsearch/search/fetch/subphase/highlight/HighlighterSearchIT.java:2637, server/src/main/java/org/elasticsearch/lucene/search/uhighlight/CustomUnifiedHighlighter.java:128]
  overlap_hints: []

- severity: Medium
  category: tests.coverage
  file: server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/AbstractHighlighterBuilder.java
  line: 568
  title: 0 is now accepted, and no test covers that boundary
  evidence: |
    -        if (maxAnalyzedOffset != null && maxAnalyzedOffset <= 0) {
    +        if (maxAnalyzedOffset != null && maxAnalyzedOffset < -1) {
  impact: 0 used to be rejected, and the old random range [-100, 0] covered it. Now it passes validation and goes to `QueryMaxAnalyzedOffset.create(0, ...)`, which builds `LimitTokenOffsetAnalyzer(..., 0)`. No test states whether 0 should be accepted or rejected, or what it produces. The intent only covers -1, so this change may not be intended and nothing would catch a regression either way.
  remedy: Decide what 0 should do. If it should be rejected, restore it in the validation and add an explicit `max_analyzed_offset: 0` case to the invalid test. If it should be accepted, add a test that states the expected highlight output, for example no highlighted terms.
  confidence: medium
  overlap_hints: [correctness.logic, spec.unrequested]

## Files examined
examined: [plugins/mapper-annotated-text/src/main/java/org/elasticsearch/index/mapper/annotatedtext/AnnotatedTextHighlighter.java, plugins/mapper-annotated-text/src/test/java/org/elasticsearch/index/mapper/annotatedtext/AnnotatedTextHighlighterTests.java, rest-api-spec/src/yamlRestTest/resources/rest-api-spec/test/search.highlight/30_max_analyzed_offset.yml, server/src/internalClusterTest/java/org/elasticsearch/search/fetch/subphase/highlight/HighlighterSearchIT.java, server/src/main/java/org/elasticsearch/lucene/search/uhighlight/CustomFieldHighlighter.java, server/src/main/java/org/elasticsearch/lucene/search/uhighlight/CustomUnifiedHighlighter.java, server/src/main/java/org/elasticsearch/lucene/search/uhighlight/QueryMaxAnalyzedOffset.java, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/AbstractHighlighterBuilder.java, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/DefaultHighlighter.java, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/PlainHighlighter.java, server/src/test/java/org/elasticsearch/lucene/search/uhighlight/CustomUnifiedHighlighterTests.java, server/src/test/java/org/elasticsearch/search/fetch/subphase/highlight/HighlightBuilderTests.java]
not_examined: []
