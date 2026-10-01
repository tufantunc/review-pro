<!-- infiniflow__ragflow@a63caa1 craft-reviewer; verbatim final answer -->
- severity: Medium
  category: craft.code-judo
  file: graphrag/general/extractor.py
  line: 204
  title: Three hand-written "extend then dedupe" pairs duplicate `flat_uniq_list`, which this file already uses
  evidence: |
    node0_attrs["source_id"].extend(node1_attrs["source_id"])
    node0_attrs["source_id"] = sorted(set(node0_attrs["source_id"]))
    ...
    edge0_attrs["keywords"].extend(edge1_attrs["keywords"])
    edge0_attrs["keywords"] = list(set(edge0_attrs["keywords"]))
    edge0_attrs["source_id"].extend(edge1_attrs["source_id"])
    edge0_attrs["source_id"] = list(set(edge0_attrs["source_id"]))
  evidence_refs: [graphrag/utils.py:543, graphrag/general/extractor.py:180]
  impact: The fix turns 3 merge expressions into 6 lines that each change the list in place before deduping it. The node path sorts the result (`sorted(set(...))`) but the edge path does not (`list(set(...))`), with no stated reason. A few lines up, `_merge_edges` already does the same job with the shared helper (`flat_uniq_list(edges_data, "keywords")`), so the file now merges list attributes two different ways. The original bug came from the hand-written idiom (`set(x.extend(y))` is `set(None)`), and copying that idiom three more times invites the next slip.
  remedy: Reuse the helper that is already imported. Use `node0_attrs["source_id"] = sorted(flat_uniq_list([node0_attrs, node1_attrs], "source_id"))`. For edges, loop once with `for attr in ("keywords", "source_id"): edge0_attrs[attr] = flat_uniq_list([edge0_attrs, edge1_attrs], attr)`. This brings back the loop over attributes the original code meant to have, removes the in-place `.extend`, and puts all merges through one helper. Also choose one ordering rule (sorted or not) for nodes and edges.
  confidence: high
  overlap_hints: [dry.duplication]

- severity: Medium
  category: craft.abstraction
  file: graphrag/utils.py
  line: 440
  title: The nursery wrapping the removed-edge deletes no longer starts any task and is now dead scaffolding (the new line also has 17-space indentation)
  evidence: |
        if change.removed_edges:
            async with trio.open_nursery() as nursery:
                for from_node, to_node in change.removed_edges:
                     await trio.to_thread.run_sync(lambda: settings.docStoreConn.delete({"knowledge_graph_kwd": ["relation"], "from_entity_kwd": from_node, "to_entity_kwd": to_node}, search.index_name(tenant_id), kb_id))
  impact: The block now runs one delete after another, but `async with trio.open_nursery() as nursery` still makes it look concurrent. The unused `nursery` name misleads readers, and linters flag it. The new line is indented 17 spaces, while every other line in the function uses multiples of 4, so the block's structure is harder to read. The other two delete calls in `set_graph` (lines 434 and 437) are plain awaited `to_thread.run_sync` calls, so this block no longer matches them.
  remedy: Delete the nursery and put the loop at function level with normal 4-space indentation, like lines 434 and 437. Use `for from_node, to_node in change.removed_edges: await trio.to_thread.run_sync(...)`. If the goal is concurrency, start the deletes with `nursery.start_soon` and bind the loop variables through default arguments or `functools.partial`. Don't keep a nursery that starts nothing.
  confidence: high
  overlap_hints: [correctness.concurrency, performance.blocking]

## Files examined
examined: [graphrag/entity_resolution.py, graphrag/general/extractor.py, graphrag/utils.py]
not_examined: []
