<!-- linera-io__linera-protocol@024925d craft-reviewer; verbatim final answer -->
## Craft findings

- severity: Medium
  category: craft.abstraction
  file: linera-core/src/updater.rs
  line: 109
  title: New `grace_period` parameter has no caller that uses it; the real change is the constant going from 0.2 to 0.1
  evidence: |
    -const GRACE_PERIOD: f64 = 0.2;
    +const DEFAULT_GRACE_PERIOD: f64 = 0.1;
    ...
    +    // Grace period as a fraction of time taken to reach quorum
    +    grace_period: impl Into<Option<f64>>,
    ...
    +    let grace_period = grace_period.into().unwrap_or(DEFAULT_GRACE_PERIOD);
    # every call site in linera-core/src/client/mod.rs:
    +            None,
  impact: The public signature of `communicate_with_quorum` gets a fifth argument, and all four call sites (client/mod.rs:1098, 1137, 1505, 1667) pass `None`. Nothing in the repo sets it. What actually changes is behaviour: the default drops from 0.2 to 0.1, and that is buried under a "make it configurable" refactor. Every reader of those call sites now meets an unexplained `None`. The doc comment also contradicts itself: "If `grace_period` is specified, other validators are given additional time" reads as if leaving it out means no grace period, yet leaving it out gives the 0.1 default. On top of that, `None`, `Some(DEFAULT_GRACE_PERIOD)` and `0.1` are three ways to say the same thing.
  remedy: Delete the parameter and the four `None` arguments. Keep the one constant, set to 0.1. If some caller really needs to set it later, add it then as a plain `f64`, or better as a field on the client's config (for example next to `max_loaded_chains` on the `Client`), and pass it through explicitly. That avoids `Option` plus a hidden default inside the helper. Either way, fix the doc comment so it describes the default behaviour correctly.
  confidence: high
  overlap_hints: [api-contract.signature, ai-antipatterns.over-engineering, spec.unrequested-behavior]
  evidence_refs: [linera-core/src/client/mod.rs:1114, linera-core/src/client/mod.rs:1150, linera-core/src/client/mod.rs:1521, linera-core/src/client/mod.rs:1679, linera-core/src/updater.rs:100]

- severity: Nitpick
  category: craft.spaghetti
  file: linera-core/src/updater.rs
  line: 141
  title: Loop label with no nested loop, trailing whitespace in comments, and a duplicate inline parameter comment
  evidence: |
    'vote_wait: while let Ok(Some((name, result))) = timeout(
    ...
            break 'vote_wait;
    ...
    /// The default amount of time we wait for additional validators to contribute 
    ...
            // If a key reaches a quorum, wait for the grace period to collect more values 
    ...
        // Grace period as a fraction of time taken to reach quorum
        grace_period: impl Into<Option<f64>>,
  impact: The loop body contains only a `match`, so the bare `break` would exit the same loop. The `'vote_wait` label hints at nesting that is not there. Lines 34 and 178 end in trailing whitespace. rustfmt usually trims that, so `cargo fmt -- --check` in CI (.github/workflows/rust.yml:296) will probably flag it. I could not run rustfmt here to confirm. The `//` comment inside the parameter list repeats the function's doc comment.
  remedy: Use a plain `break;` and drop the label. Remove the trailing whitespace on lines 34 and 178 (run `cargo fmt`). Remove the inline parameter comment; this goes away anyway if the parameter is deleted as in the finding above.
  confidence: medium
  overlap_hints: [ai-antipatterns.ignored-conventions]
  evidence_refs: [linera-core/src/updater.rs:34, linera-core/src/updater.rs:108, linera-core/src/updater.rs:175, linera-core/src/updater.rs:178]

Out of my scope, but worth routing to the correctness reviewer: the loop now `break`s as soon as quorum becomes impossible, where it used to wait out the grace period. Error outcomes can now be decided on less information. This behaviour change is mixed into a commit described as a "configurable" refactor.

The typo fixes in client/mod.rs and node.rs have no craft impact. Note that node.rs still says "ceritifcates" in the message it just edited. The worker.rs doc-comment and attribute reorder is a small improvement.

## Files examined
examined: [linera-core/src/client/mod.rs, linera-core/src/node.rs, linera-core/src/updater.rs, linera-core/src/worker.rs]
not_examined: []
