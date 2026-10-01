<!-- infiniflow__ragflow@a63caa1 performance-reviewer; verbatim final answer -->
## Performance findings

- severity: Medium
  category: performance.n-plus-1
  file: graphrag/utils.py
  line: 442
  title: Removed edges are deleted one at a time, each as a delete-by-query with refresh=True
  evidence: |
        if change.removed_edges:
            async with trio.open_nursery() as nursery:
                for from_node, to_node in change.removed_edges:
                     await trio.to_thread.run_sync(lambda: settings.docStoreConn.delete({"knowledge_graph_kwd": ["relation"], "from_entity_kwd": from_node, "to_entity_kwd": to_node}, search.index_name(tenant_id), kb_id))
  evidence_refs: [rag/utils/es_conn.py:439, graphrag/general/extractor.py:207, graphrag/general/index.py:252]
  impact: |
    Each removed edge causes one `es.delete_by_query(..., refresh=True)` call (es_conn.py:439-442), and the next call only starts when the previous one finishes. Every call waits for a full search, a delete and an index refresh, and it can retry with a 3s sleep on timeout.
    The edges come from entity resolution: `_merge_graph_nodes` adds every edge touching each merged-away node (extractor.py:207), and `set_graph` deletes them at index.py:252. On a knowledge graph of a few thousand entities, resolution can merge hundreds of nodes and remove thousands of edges.
    At about 50-200 ms per refreshed delete-by-query, 2,000 edges take roughly 2-7 minutes of serial ES round trips. Each refresh also loads the shared tenant index.
    Removed nodes are already deleted in one batched `terms` query just above (line 437), so edges are the one part of this function that costs one query per item.
    The nursery is now unused, so the sequential order is accidental. The old `start_soon(lambda: <sync call>)` was broken: it ran the delete synchronously on the event loop and then raised, because the lambda did not return a coroutine. So this change fixes a crash, but leaves an unbatched loop that grows with the number of removed edges.
  remedy: |
    Every edge in `removed_edges` has one endpoint in `removed_nodes` (extractor.py:207 adds `(node1, neighbor)` for each node1 in `nodes[1:]`). So two batched queries replace the loop:
    `delete({"knowledge_graph_kwd": ["relation"], "from_entity_kwd": sorted(change.removed_nodes)}, ...)` and the same with `"to_entity_kwd"`. ES `delete` already turns list values into `terms` (es_conn.py:429-430).
    If deleting per pair must stay, run the calls concurrently through the nursery with an async wrapper and a `trio.CapacityLimiter`. Bind loop variables with default arguments (`lambda f=from_node, t=to_node: ...`) to avoid late binding. Either way, drop the unused nursery.
  confidence: medium
  overlap_hints: [db.query, backend.transaction]

The `extractor.py` change (an in-place `extend` and then `sorted(set(...))` for each merged node) and the `entity_resolution.py` change (`list(sub_connect_graph)`) add no meaningful cost. The per-merge sort is O(k log k) on small source_id and keyword lists, which is not a finding.

## Files examined
examined: [graphrag/utils.py, graphrag/general/extractor.py, graphrag/entity_resolution.py]
not_examined: []
