<!-- linera-io__linera-protocol@024925d performance-reviewer; verbatim final answer -->
## Performance findings: none

This change doesn't make anything slower. Both changes to `communicate_with_quorum` in `/Users/tufantunc/Desktop/Projects/Personal/aacr-bench/evaluation/work/linera-io__linera-protocol@024925d/linera-core/src/updater.rs` shorten how long the call waits:

- **Early exit:** when no key can reach a quorum any more, the loop now exits immediately at line 175 (`break 'vote_wait`). Before, it set a grace deadline and kept waiting, so this is equal or lower latency.
- **Shorter default grace period:** the default fraction drops from 0.2 to 0.1 (`DEFAULT_GRACE_PERIOD`). All four callers in `client/mod.rs` pass `None`, so each one waits half as long after reaching a quorum.
- **No extra work:** the per-response work is still one weight subtraction and one HashMap update, and the grace fraction is resolved once, outside the loop. Dropping the `FuturesUnordered` on the early exit cancels in-flight validator requests, the same way the old deadline timeout did.

The shorter default may leave slow validators unupdated more often, so more catch-up syncing could happen later. Whether that matters depends on how the protocol and validators behave, not on this code path. Nothing here shows it happening, so I haven't filed it as a finding.

The edits to `node.rs`, `worker.rs` and the non-argument parts of `client/mod.rs` are typo, comment and attribute-order fixes with no runtime effect.

## Files examined
examined: [linera-core/src/client/mod.rs, linera-core/src/node.rs, linera-core/src/updater.rs, linera-core/src/worker.rs]
not_examined: []
