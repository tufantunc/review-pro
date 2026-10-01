<!-- linera-io__linera-protocol@024925d correctness-reviewer; verbatim final answer -->
- severity: High
  category: correctness.logic
  file: linera-core/src/updater.rs
  line: 174
  title: Breaking out of the loop as soon as quorum becomes impossible stops errors from ever becoming Trusted
  evidence: |
    // If it becomes clear that no key can reach a quorum, break early.
    if highest_key_score + remaining_votes < committee.quorum_threshold() {
        break 'vote_wait;
    }
  impact: |
    The old code started a grace period when no key could reach quorum. That extra time let more errors arrive, so an error could reach `validity_threshold` and return `CommunicationError::Trusted(err)` at line 169. The new code breaks at once and falls through to `CommunicationError::Sample` at line 208.

    Example: a committee of 4 equal-weight validators (quorum 3, validity 2), where one validator is offline. The offline one fails first with a ClientIoError, and the next one returns `InactiveChain(chain_id)`. Now `remaining_votes = 2` and `highest_key_score = 0`, so `0 + 2 < 3` and the loop breaks. The third `InactiveChain` reply, which would have made the error Trusted, is never read.

    `find_received_certificates` (linera-core/src/client/mod.rs:1526) returns `Ok(())` only on `Trusted(NodeError::InactiveChain(id))`. Any other error propagates (line 1531-1532). So for an inactive or not-yet-active chain, one offline or lagging validator (within the BFT fault budget) now makes `find_received_certificates` fail every time. Before, it usually succeeded.

    The same thing happens anywhere callers or tests expect a Trusted error. `test_request_leader_timeout` (client_tests.rs:1838-1851) already allows Sample only for the "fast responders disagree" race. That race used to be narrowed by the grace period and is now the deterministic outcome.
  remedy: Keep a grace period when no key can reach quorum (as the old code did) so more error responses can arrive. At minimum, keep reading responses while some error could still reach `validity_threshold` (`max_error_score + remaining_votes >= validity_threshold`) before breaking.
  confidence: medium
  evidence_refs: [linera-core/src/client/mod.rs:1526, linera-core/src/client/mod.rs:1531, linera-core/src/updater.rs:166, linera-core/src/updater.rs:208, linera-core/src/unit_tests/client_tests.rs:1838]
  overlap_hints: [tests.coverage, spec]

- severity: Low
  category: correctness.error-path
  file: linera-core/src/updater.rs
  line: 181
  title: The new public grace_period parameter is not validated before Duration::mul_f64, which panics
  evidence: |
    let grace_period = grace_period.into().unwrap_or(DEFAULT_GRACE_PERIOD);
    ...
    end_time = Some(Instant::now() + start_time.elapsed().mul_f64(grace_period));
  impact: '`communicate_with_quorum` is `pub` and now takes any caller `f64`. `Duration::mul_f64` panics if the result is negative, non-finite (NaN or inf) or overflows. So `Some(-0.1)`, `Some(f64::NAN)` or a huge value would panic the client task once quorum is reached. None of the 4 current callers (client/mod.rs:1114, 1150, 1521, 1679) passes anything but `None`, so today this is latent.'
  remedy: Clamp or validate the value, e.g. `grace_period.filter(|g| g.is_finite() && *g >= 0.0).unwrap_or(DEFAULT_GRACE_PERIOD)`, or use `Duration::try_from_secs_f64` or `checked_*`. Also consider taking a validated type.
  confidence: high
  overlap_hints: [api-contract, backend]

- severity: Low
  category: correctness.devex
  file: linera-core/src/updater.rs
  line: 34
  title: Trailing whitespace in new comments will likely fail CI's cargo fmt --check
  evidence: |
    +/// The default amount of time we wait for additional validators to contribute 
    ...
    +        // If a key reaches a quorum, wait for the grace period to collect more values 
  impact: Lines 34 and 178 end with a trailing space, as the diff shows. rustfmt trims trailing whitespace in comments, so `cargo fmt -- --check` (.github/workflows/rust.yml:296) would probably report a diff and fail the format job. I could not run rustfmt here, so this is unconfirmed.
  remedy: Remove the trailing spaces, or run `cargo fmt`.
  confidence: medium
  evidence_refs: [.github/workflows/rust.yml:296]
  overlap_hints: [craft]

## Files examined
examined: [linera-core/src/updater.rs, linera-core/src/client/mod.rs, linera-core/src/node.rs, linera-core/src/worker.rs]
not_examined: []
