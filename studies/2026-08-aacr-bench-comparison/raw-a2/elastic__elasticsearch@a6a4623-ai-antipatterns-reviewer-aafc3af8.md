<!-- elastic__elasticsearch@a6a4623 ai-antipatterns-reviewer; verbatim final answer -->
## AI-Antipatterns findings

- severity: Medium
  category: ai-antipatterns.ignored-convention
  file: server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/AbstractHighlighterBuilder.java
  line: 568
  title: Validation relaxed to accept -1 (and 0) with no TransportVersion gating on a field that is sent over the wire
  evidence: |
    if (maxAnalyzedOffset != null && maxAnalyzedOffset < -1) {
        throw new IllegalArgumentException("[" + MAX_ANALYZED_OFFSET_FIELD + "] must be an integer >= -1");
  impact: The change assumes the new value range only matters on this node. It doesn't. The value goes over the wire unchanged through `out.writeOptionalInt(maxAnalyzedOffset)` (AbstractHighlighterBuilder.java:212). The receiving node runs it back through this same setter via `maxAnalyzedOffset(in.readOptionalInt())` (line 168). In a mixed-version cluster, a new coordinating node will send `-1` (or `0`) to an older data node. The older node still has the `<= 0` check, so it throws `IllegalArgumentException` while deserializing the shard request. The repo normally gates changes like this with a TransportVersion. Here there is no TransportVersion check and no rewrite of `-1` for older receivers.
  remedy: Add a TransportVersion. In `writeTo`, when `out.getTransportVersion()` is older than it and the value is `-1`, write `null` instead, or reject the request. Also decide on purpose whether `0` should now be valid. The old code rejected it and nothing in the intent asks for it.
  confidence: medium
  evidence_refs: [server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/AbstractHighlighterBuilder.java:168, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/AbstractHighlighterBuilder.java:212]
  overlap_hints: [api-contract.back-compat, correctness.cross-file]

- severity: Medium
  category: ai-antipatterns.hallucination
  file: server/src/test/java/org/elasticsearch/search/fetch/subphase/highlight/HighlightBuilderTests.java
  line: 580
  title: Only the expected message was updated. The random invalid range still includes values that are now valid
  evidence: |
    "{ \"max_analyzed_offset\" : " + randomIntBetween(-100, 0) + "}"
    ...
    assertThat(e.getCause().getMessage(), containsString("[max_analyzed_offset] must be an integer >= -1"));
  impact: The test still treats every value in [-100, 0] as invalid. After this change, `-1` and `0` pass the `< -1` check at AbstractHighlighterBuilder.java:568. `randomIntBetween` includes both ends, so about 2 runs in 101 draw one of those values, `expectParseThrows` fails, and the test is flaky.
  remedy: Use `randomIntBetween(-100, -2)` so every drawn value is invalid. Add a positive test showing `-1` parses correctly.
  confidence: high
  evidence_refs: [server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/AbstractHighlighterBuilder.java:568]
  overlap_hints: [tests.flaky, correctness.logic]

- severity: Medium
  category: ai-antipatterns.ignored-convention
  file: rest-api-spec/src/yamlRestTest/resources/rest-api-spec/test/search.highlight/30_max_analyzed_offset.yml
  line: 133
  title: YAML test now expects the new error message but is still gated only on gte_v7.12.0
  evidence: |
    - requires:
        cluster_features: ["gte_v7.12.0"]
    ...
    - match: { error.caused_by.reason: "[max_analyzed_offset] must be an integer >= -1" }
  impact: In BWC or mixed-cluster YAML runs, any node from 7.12 up to the previous release returns "must be a positive integer", so this match fails. The repo gates new REST behavior with capabilities. One example is `capabilities: [ range_regexp_interval_queries ]` plus `test_runner_features: capabilities` (search/230_interval_query.yml:485-486), backed by `SearchCapabilities.CAPABILITIES` (server/src/main/java/org/elasticsearch/rest/action/search/SearchCapabilities.java:52). There is also no YAML test for the new `-1` behavior.
  remedy: Add a capability to `SearchCapabilities` (for example `highlight_max_analyzed_offset_default`). Gate the changed test on it, and add a gated YAML test that runs `max_analyzed_offset: -1`.
  confidence: high
  evidence_refs: [rest-api-spec/src/yamlRestTest/resources/rest-api-spec/test/search/230_interval_query.yml:485, server/src/main/java/org/elasticsearch/rest/action/search/SearchCapabilities.java:52]
  overlap_hints: [tests.coverage, api-contract.back-compat]

- severity: Low
  category: ai-antipatterns.ignored-convention
  file: server/src/main/java/org/elasticsearch/lucene/search/uhighlight/QueryMaxAnalyzedOffset.java
  line: 12
  title: Hand-written value class with a misplaced comment, where a record would do
  evidence: |
    public class QueryMaxAnalyzedOffset {
        private final int queryMaxAnalyzedOffset;

        private QueryMaxAnalyzedOffset(final int queryMaxAnalyzedOffset) {
            // If we have a negative value, grab value for the actual maximum from the index.
            this.queryMaxAnalyzedOffset = queryMaxAnalyzedOffset;
        }
  impact: The constructor comment describes what `create()` does, not the constructor, which only assigns the field. The type is a single-int wrapper with an unusually named accessor, `getNotNull()`. It still comes back as `null` from `create`, so every call site keeps its null checks. ES normally writes small value types like this as records.
  remedy: Replace it with `public record QueryMaxAnalyzedOffset(int value)` plus the static `create` factory. Move the comment onto `create` and drop `getNotNull()`.
  confidence: medium
  overlap_hints: [craft.abstraction]

- severity: Low
  category: ai-antipatterns.ignored-convention
  file: server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/AbstractHighlighterBuilder.java
  line: 564
  title: The javadoc, the validation and the resolver disagree on which negative values are valid, and user docs and changelog weren't updated
  evidence: |
    * "maxAnalyzedOffset" might be non-negative int, null (unknown), or a negative int (defaulting to index analyzed offset).
    ...
    if (maxAnalyzedOffset != null && maxAnalyzedOffset < -1) {
  impact: The javadoc says any negative int means "use the index default", and `QueryMaxAnalyzedOffset.create` resolves any `< 0` that way. The validation only allows `-1`. docs/reference/search/search-your-data/highlighting.asciidoc:261 still only describes non-negative values. No docs/changelog/*.yaml entry was added for this user-visible REST change; `git diff --name-status` shows only QueryMaxAnalyzedOffset.java as a new file.
  remedy: Say "-1" explicitly in the javadoc and treat `== -1` as the only sentinel. Document `-1` in highlighting.asciidoc and add a docs/changelog entry.
  confidence: medium
  evidence_refs: [docs/reference/search/search-your-data/highlighting.asciidoc:261, server/src/main/java/org/elasticsearch/lucene/search/uhighlight/QueryMaxAnalyzedOffset.java:24]
  overlap_hints: [spec.missing, craft.boundary]

## Files examined
examined: [plugins/mapper-annotated-text/src/main/java/org/elasticsearch/index/mapper/annotatedtext/AnnotatedTextHighlighter.java, plugins/mapper-annotated-text/src/test/java/org/elasticsearch/index/mapper/annotatedtext/AnnotatedTextHighlighterTests.java, rest-api-spec/src/yamlRestTest/resources/rest-api-spec/test/search.highlight/30_max_analyzed_offset.yml, server/src/internalClusterTest/java/org/elasticsearch/search/fetch/subphase/highlight/HighlighterSearchIT.java, server/src/main/java/org/elasticsearch/lucene/search/uhighlight/CustomFieldHighlighter.java, server/src/main/java/org/elasticsearch/lucene/search/uhighlight/CustomUnifiedHighlighter.java, server/src/main/java/org/elasticsearch/lucene/search/uhighlight/QueryMaxAnalyzedOffset.java, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/AbstractHighlighterBuilder.java, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/DefaultHighlighter.java, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/PlainHighlighter.java, server/src/test/java/org/elasticsearch/lucene/search/uhighlight/CustomUnifiedHighlighterTests.java, server/src/test/java/org/elasticsearch/search/fetch/subphase/highlight/HighlightBuilderTests.java]
not_examined: []
