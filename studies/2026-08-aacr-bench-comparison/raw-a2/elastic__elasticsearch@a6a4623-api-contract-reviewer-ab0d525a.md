<!-- elastic__elasticsearch@a6a4623 api-contract-reviewer; verbatim final answer -->
## API-Contract findings

- severity: High
  category: api-contract.breaking
  file: server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/AbstractHighlighterBuilder.java
  line: 568
  title: -1 and 0 are now accepted and sent to other nodes with no TransportVersion gate, so older data nodes fail to read the request
  evidence: |
    public HB maxAnalyzedOffset(Integer maxAnalyzedOffset) {
        if (maxAnalyzedOffset != null && maxAnalyzedOffset < -1) {
            throw new IllegalArgumentException("[" + MAX_ANALYZED_OFFSET_FIELD + "] must be an integer >= -1");
        }
    ...
    // readFrom (line 168):  maxAnalyzedOffset(in.readOptionalInt());
    // writeTo  (line 212):  out.writeOptionalInt(maxAnalyzedOffset);
  evidence_refs: [server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/AbstractHighlighterBuilder.java:168, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/AbstractHighlighterBuilder.java:212]
  impact: The new wire value -1 (and 0) is written with `writeOptionalInt` for every stream version. The other fields in this class are gated on `TransportVersions.V_8_14_0` (lines 144/180); this one is not. During a rolling upgrade (8.x to 9.0), a new-version coordinator accepts `max_analyzed_offset: -1` and forwards the highlight builder inside the shard request. An old data node deserializes it through `readFrom`, which calls the old setter and rejects values `<= 0` with "must be a positive integer". The error is thrown while reading the transport request, so the result is shard failures (or a failed search) caused by a deserialization error, not a clean 400. How often this happens depends on users sending the new value mid-upgrade.
  remedy: Add a new TransportVersion. In `writeTo`, when `out.getTransportVersion()` is before it and the value is `<= 0`, fail with a clear IllegalArgumentException, for example "max_analyzed_offset=-1 requires all nodes on version X". Don't silently rewrite the value to null, because null means something else (error when the text exceeds the index limit). Alternatively, reject -1 on the coordinator until the cluster's minimum version supports it.
  confidence: high
  overlap_hints: [backend.validation, correctness.bwc]

- severity: Medium
  category: api-contract.breaking
  file: rest-api-spec/src/yamlRestTest/resources/rest-api-spec/test/search.highlight/30_max_analyzed_offset.yml
  line: 133
  title: The REST error message changed without a skipTest for the compatibility suite or a version gate for mixed clusters
  evidence: |
    -"Plain highlighter with max_analyzed_offset < 0 should FAIL":
    +"Plain highlighter with max_analyzed_offset < -1 should FAIL":
       - requires:
           cluster_features: ["gte_v7.12.0"]
    ...
    -  - match: { error.caused_by.reason: "[max_analyzed_offset] must be a positive integer" }
    +  - match: { error.caused_by.reason: "[max_analyzed_offset] must be an integer >= -1" }
  evidence_refs: [rest-api-spec/build.gradle:57, qa/mixed-cluster/build.gradle:28, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/AbstractHighlighterBuilder.java:569]
  impact: |
    Both suites that check this response will fail:
    (1) yamlRestCompatTest runs the 8.x copy of `search.highlight/30_max_analyzed_offset/Plain highlighter with max_analyzed_offset < 0 should FAIL` against this 9.0.0 node. That copy sends -10, which is still rejected, but it expects the reason "must be a positive integer" and now gets "must be an integer >= -1". The `yamlRestCompatTestTransform` block in rest-api-spec/build.gradle has no `task.skipTest` entry for this test.
    (2) qa/mixed-cluster runs the core rest-api-spec yaml tests. The renamed test is still gated only on `gte_v7.12.0`, so it runs against mixed clusters. Validation happens in the REST parser of the node that receives the request, so when an old node receives it, the reason is the old text and the match fails.
    More broadly, the user-visible 400 reason text changed. That is minor, but it is what these suites exist to check.
  remedy: Add `task.skipTest("search.highlight/30_max_analyzed_offset/Plain highlighter with max_analyzed_offset < 0 should FAIL", "error message changed")` to rest-api-spec/build.gradle. Gate the renamed test (and any new -1 test) on a new cluster feature so mixed clusters with pre-change nodes skip it. Or keep the old message prefix so both versions match.
  confidence: high
  overlap_hints: [tests.bwc]

- severity: Low
  category: api-contract.schema
  file: server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/AbstractHighlighterBuilder.java
  line: 564
  title: The docs for max_analyzed_offset still don't mention the new -1 value
  evidence: |
    * "maxAnalyzedOffset" might be non-negative int, null (unknown), or a negative int (defaulting to index analyzed offset).
    // docs/reference/search/search-your-data/highlighting.asciidoc:261-270 (unchanged):
    // "If this setting is set to a non-negative value, the highlighting stops at this defined maximum limit..."
  evidence_refs: [docs/reference/search/search-your-data/highlighting.asciidoc:261]
  impact: The request contract now has a special value (-1 means "use index.highlight.max_analyzed_offset, and truncate instead of erroring"), but the only public schema description, highlighting.asciidoc, is not in the change and says nothing about it. The javadoc also says "a negative int" defaults to the index value, while validation only accepts -1 and rejects anything below it. REST clients and spec generators working from the docs won't find the feature, and the javadoc misstates which values are allowed.
  remedy: Document `-1` in highlighting.asciidoc under max-analyzed-offset, including that it truncates at the index setting instead of erroring. Change the javadoc to say "-1" instead of "a negative int".
  confidence: high
  overlap_hints: [spec.missing]

## Files examined
examined: [plugins/mapper-annotated-text/src/main/java/org/elasticsearch/index/mapper/annotatedtext/AnnotatedTextHighlighter.java, rest-api-spec/src/yamlRestTest/resources/rest-api-spec/test/search.highlight/30_max_analyzed_offset.yml, server/src/main/java/org/elasticsearch/lucene/search/uhighlight/CustomFieldHighlighter.java, server/src/main/java/org/elasticsearch/lucene/search/uhighlight/CustomUnifiedHighlighter.java, server/src/main/java/org/elasticsearch/lucene/search/uhighlight/QueryMaxAnalyzedOffset.java, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/AbstractHighlighterBuilder.java, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/DefaultHighlighter.java, server/src/main/java/org/elasticsearch/search/fetch/subphase/highlight/PlainHighlighter.java]
not_examined:
  - file: plugins/mapper-annotated-text/src/test/java/org/elasticsearch/index/mapper/annotatedtext/AnnotatedTextHighlighterTests.java
    reason: test-only change and outside the API-contract scope; I didn't read its diff
  - file: server/src/internalClusterTest/java/org/elasticsearch/search/fetch/subphase/highlight/HighlighterSearchIT.java
    reason: test-only change and outside the API-contract scope; I didn't read its diff
  - file: server/src/test/java/org/elasticsearch/lucene/search/uhighlight/CustomUnifiedHighlighterTests.java
    reason: test-only change and outside the API-contract scope; I didn't read its diff
  - file: server/src/test/java/org/elasticsearch/search/fetch/subphase/highlight/HighlightBuilderTests.java
    reason: test-only change and outside the API-contract scope; I didn't read its diff
