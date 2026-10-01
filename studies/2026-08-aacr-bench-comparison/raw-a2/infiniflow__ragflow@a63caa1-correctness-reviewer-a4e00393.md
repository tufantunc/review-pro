<!-- infiniflow__ragflow@a63caa1 correctness-reviewer; verbatim final answer -->
- severity: Low
  category: correctness.side-effect
  file: graphrag/general/extractor.py
  line: 223
  title: Fixed merge path now runs, but edges moved onto the kept node are not added to change.added_updated_edges
  evidence: |
                change.removed_edges.add(get_from_to(node1, neighbor))
                if neighbor not in nodes_set:
                    ...
                    else:
                        graph.add_edge(nodes[0], neighbor, **edge1_attrs)
  impact: |
    Line 223 itself is unchanged. Before this commit, `_merge_graph_nodes` could never reach it. `sub_connect_graph.nodes` raised AttributeError on a set, and `set(list.extend(...))` raised TypeError on None. After the fix, line 223 runs. When node1 has a neighbor X that is not a neighbor of nodes[0], two things happen. First, the edge (node1, X) goes into `change.removed_edges`, so `set_graph` (graphrag/utils.py:439-442) deletes its relation chunk from the doc store. Second, the new edge (nodes[0], X) goes into the in-memory graph but not into `change.added_updated_edges`. As a result, `set_graph` (utils.py:461-463) never writes a relation chunk for it. The graph JSON blob holds the edge, but the per-relation index loses it. Retrieval reads that index (graphrag/search.py), and `rebuild_graph` would rebuild the graph without it.
  remedy: In the `else` branch, add `change.added_updated_edges.add(get_from_to(nodes[0], neighbor))` before `graph.add_edge(...)`.
  confidence: medium
  overlap_hints: [correctness.logic]

The changed lines themselves are correct:
- **entity_resolution.py:114.** `nx.connected_components` returns sets, so `list(sub_connect_graph)` is correct. The lambda passed to `trio.Nursery.start_soon` is called synchronously inside `start_soon`, which builds the coroutine immediately. So `merging_nodes` gets bound on each pass of the loop, and late binding is not a problem.
- **extractor.py:204-205 and 216-219.** Nodes are built in `index.py:140-142` and `graph_merge`. They carry `source_id` as a list and have no `keywords`, so removing the `keywords` merge for nodes fixes a KeyError. Edges always have a list `keywords`: `tidy_graph` adds a default (utils.py:184-185) and `_merge_edges` fills it via `flat_uniq_list`. Edge `source_id` is a list (index.py:150). Extending in place and then deduplicating is correct.
- **utils.py:442.** `docStoreConn.delete` is synchronous, so the old `start_soon(lambda: <sync call>)` raised TypeError. The new `await trio.to_thread.run_sync(...)` runs one delete per pass of the loop, which also removes the late-binding risk. Indenting by 17 spaces is valid because it is the only statement in the `for` body. The nursery that wraps it no longer does anything, but that is harmless.

## Files examined
examined: [graphrag/entity_resolution.py, graphrag/general/extractor.py, graphrag/utils.py]
not_examined: []
