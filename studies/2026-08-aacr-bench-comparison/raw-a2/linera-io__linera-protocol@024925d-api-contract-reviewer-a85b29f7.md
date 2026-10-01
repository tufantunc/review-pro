<!-- linera-io__linera-protocol@024925d api-contract-reviewer; verbatim final answer -->
## API-Contract findings

- severity: Medium
  category: api-contract.breaking
  file: linera-core/src/updater.rs
  line: 174
  title: Stopping as soon as no quorum is possible makes `communicate_with_quorum` return `Sample` in cases that used to return `Trusted`
  evidence: |
    // If it becomes clear that no key can reach a quorum, break early.
    if highest_key_score + remaining_votes < committee.quorum_threshold() {
        break 'vote_wait;
    }
    // (was: end_time = Some(Instant::now() + start_time.elapsed().mul_f64(GRACE_PERIOD))
    //  for BOTH the quorum-reached and the no-quorum-possible conditions)
  impact: Before this change, once no quorum was possible the function still waited for the grace period. During that wait, more copies of the same error could arrive and push it past `validity_threshold()`, which returns `CommunicationError::Trusted(err)`. Now the loop exits at once and falls through to `CommunicationError::Sample(..)`. This changes which error variant a public function returns, and one consumer depends on that variant: `linera-core/src/client/mod.rs:1526` matches `Err(CommunicationError::Trusted(NodeError::InactiveChain(id))) if id == chain_id` and treats it as `return Ok(())`. Take 4 validators of equal weight (quorum 3, validity 2). One faulty validator returns some error X and one honest validator returns `InactiveChain`. At that point highest score 0 plus 2 remaining is less than 3, so the loop breaks with `Sample`. The old code would have waited for the other honest validators' `InactiveChain` and returned `Trusted`. As a result, `synchronize_received_certificates` now fails for an inactive chain where it used to return `Ok(())`. The test at `linera-core/src/unit_tests/client_tests.rs:1841-1851` already accepts either variant because of this exact timing sensitivity, and the change makes the `Sample` outcome more likely. The commit calls this a refactor that makes the grace period configurable and does not mention the behaviour change.
  remedy: Keep the grace-period wait for the no-quorum case, i.e. set `end_time` instead of breaking, as before. If the early exit is intended, document the new error semantics and make the `InactiveChain` consumer at client/mod.rs:1526 also handle a `Sample` in which `InactiveChain` dominates.
  confidence: medium
  evidence_refs: [linera-core/src/client/mod.rs:1526, linera-core/src/updater.rs:162-167, linera-core/src/unit_tests/client_tests.rs:1841]
  overlap_hints: [correctness.logic, backend.error-handling]

- severity: Medium
  category: api-contract.breaking
  file: linera-core/src/updater.rs
  line: 36
  title: Default grace period silently halved from 0.2 to 0.1 for every existing caller
  evidence: |
    -const GRACE_PERIOD: f64 = 0.2;
    +const DEFAULT_GRACE_PERIOD: f64 = 0.1;
    ...
    let grace_period = grace_period.into().unwrap_or(DEFAULT_GRACE_PERIOD);
  impact: All four callers pass `None` (`linera-core/src/client/mod.rs:1114, 1150, 1521, 1679`), so each of them now gets a grace window half as long. That affects how many validators get the chance to contribute votes, values or errors after quorum. For example, the `communicate_chain_action` result at client/mod.rs:1137 gathers votes for certificates, and the received-certificate sync at client/mod.rs:1505 collects certificate batches from validators. The commit message only says "Make the communicate_with_quorum grace period configurable", so this default change is undeclared.
  remedy: Keep `DEFAULT_GRACE_PERIOD = 0.2` so the refactor preserves behaviour. If 0.1 is intended, make that change separately and state it explicitly, or pass `Some(0.2)` at the call sites that need the old window.
  confidence: high
  evidence_refs: [linera-core/src/client/mod.rs:1114, linera-core/src/client/mod.rs:1150, linera-core/src/client/mod.rs:1521, linera-core/src/client/mod.rs:1679]
  overlap_hints: [correctness.behavior-change, spec.unrequested-behavior]

- severity: Low
  category: api-contract.types
  file: linera-core/src/updater.rs
  line: 109
  title: Public `grace_period: impl Into<Option<f64>>` accepts values that make `Duration::mul_f64` panic
  evidence: |
    // Grace period as a fraction of time taken to reach quorum
    grace_period: impl Into<Option<f64>>,
    ...
    end_time = Some(Instant::now() + start_time.elapsed().mul_f64(grace_period));
  impact: The new public parameter is an unchecked `f64`. `Duration::mul_f64` panics on negative, NaN, infinite or overflowing results, so `Some(-0.1)` or `Some(f64::NAN)` would panic inside the quorum loop. That would crash the client task instead of returning an error. Today no caller passes `Some`, since all four pass `None`, so the problem is latent. The type also blurs `None` ("use the default") with `Some(0.0)` ("no grace"). The doc comment makes this worse: it says "If `grace_period` is specified, other validators are given additional time", but a default grace period still applies when it is `None`.
  remedy: Accept a validated type, such as a newtype checked for finite, non-negative values or a `Duration`-based setting, or clamp and reject bad values before calling `mul_f64`. Fix the doc so it says the default applies when the value is `None`.
  confidence: high
  overlap_hints: [backend.validation, correctness.panic]

No contract issues in `linera-core/src/node.rs`. Only the `#[error]` display text of `MissingCertificates` changed. Serde and the format snapshot use variant names (`linera-rpc/tests/snapshots/format__format.yaml.snap:579`), and no code matches on the string. No contract issues in `linera-core/src/worker.rs` either: the change there is a doc comment and an attribute reorder. The extra positional parameter on the public `communicate_with_quorum` breaks the signature, but `git grep` finds callers only in `linera-core/src/client/mod.rs`, and all of them are updated.

## Files examined
examined: [linera-core/src/client/mod.rs, linera-core/src/node.rs, linera-core/src/updater.rs, linera-core/src/worker.rs]
not_examined: []
