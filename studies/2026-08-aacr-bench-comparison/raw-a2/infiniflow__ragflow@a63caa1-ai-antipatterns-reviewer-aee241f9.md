<!-- infiniflow__ragflow@a63caa1 ai-antipatterns-reviewer; verbatim final answer -->
## AI-Antipatterns findings

- severity: Medium
  category: ai-antipatterns.ignored-convention
  file: graphrag/utils.py
  line: 440
  title: The fix swaps the call inside the loop but leaves an empty nursery around it, indented 17 spaces
  evidence: |
        if change.removed_edges:
            async with trio.open_nursery() as nursery:
                for from_node, to_node in change.removed_edges:
                     await trio.to_thread.run_sync(lambda: settings.docStoreConn.delete({"knowledge_graph_kwd": ["relation"], "from_entity_kwd": from_node, "to_entity_kwd": to_node}, search.index_name(tenant_id), kb_id))
  impact: The original bug was real. `nursery.start_soon` was handed a lambda that returns a non-coroutine, because `docStoreConn.delete` is synchronous. The fix makes each delete a sequential `await` instead, so `nursery` is now never used. The `async with trio.open_nursery()` block does nothing, and it suggests concurrency that isn't there. The function's own convention, two statements up, is a direct `await trio.to_thread.run_sync(...)` with no nursery (graphrag/utils.py:434 and :437). The added line is also indented 17 spaces against the file's 4-space steps. It is valid Python only because it is the loop's only statement. Both signs point to a line edited in place without reading the code around it.
  remedy: Delete the `async with trio.open_nursery() as nursery:` line and dedent the loop so it matches :437. If concurrency was the goal, keep the nursery and use `nursery.start_soon(trio.to_thread.run_sync, partial(settings.docStoreConn.delete, ...))`. Bind `from_node`/`to_node` explicitly in that case, so each task keeps its own values.
  confidence: high
  evidence_refs: [graphrag/utils.py:434, graphrag/utils.py:437]
  overlap_hints: [craft.boundary, performance.blocking]

- severity: Low
  category: ai-antipatterns.ignored-convention
  file: graphrag/general/extractor.py
  line: 216
  title: Merges lists with hand-written extend+set instead of the `flat_uniq_list` helper the module already imports
  evidence: |
                            edge0_attrs["keywords"].extend(edge1_attrs["keywords"])
                            edge0_attrs["keywords"] = list(set(edge0_attrs["keywords"]))
                            edge0_attrs["source_id"].extend(edge1_attrs["source_id"])
                            edge0_attrs["source_id"] = list(set(edge0_attrs["source_id"]))
  impact: This module already imports `flat_uniq_list(arr, key)` (extractor.py:26). That helper flattens one key across a list of dicts and de-duplicates the result (graphrag/utils.py:543-551). The same file uses it for this exact keywords/source_id merge at :180-181. The new code repeats that logic in 4 lines here and 2 more at :204-205. It also changes `edge0_attrs` lists in place before reassigning them.
  remedy: Replace the block with `edge0_attrs["keywords"] = flat_uniq_list([edge0_attrs, edge1_attrs], "keywords")` and `edge0_attrs["source_id"] = flat_uniq_list([edge0_attrs, edge1_attrs], "source_id")`. Do the same for the node: `node0_attrs["source_id"] = sorted(flat_uniq_list([node0_attrs, node1_attrs], "source_id"))`.
  confidence: high
  evidence_refs: [graphrag/general/extractor.py:26, graphrag/general/extractor.py:180, graphrag/utils.py:543]
  overlap_hints: [dry.canonical-helper]

Both finding blocks omit the `verdict` field, because no verification pass ran on them.

Two other changes were checked and are fine. In entity_resolution.py:114, `list(sub_connect_graph)` is correct: `nx.connected_components` yields `set`s, so the old `.nodes` call was the made-up API, and this change removes it. In extractor.py, the node merge stops touching `"keywords"`, and that is consistent with the code: node data never carries `keywords` (only edges do, at :180-186).

## Files examined
examined: [graphrag/entity_resolution.py, graphrag/general/extractor.py, graphrag/utils.py]
not_examined: []
