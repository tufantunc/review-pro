<!-- mpv-player__mpv@dbd327d tests-reviewer; verbatim final answer -->
The change adds a new public function, `mp_rand_in_range32()`, changes `playlist_shuffle()` from a relative to an absolute swap index, and refactors the PRNG to state held by the caller. No test was added or changed. The test harness already links `misc/random.c` into `test_utils` (`test/meson.build:20`) and provides `assert_true` and `assert_int_equal` (`test/test_utils.h:9-11`, used the same way in `test/timer.c`), so every case below can be written with what exists today.

- severity: Medium
  category: tests.coverage
  file: misc/random.c
  line: 90
  title: new mp_rand_in_range32() has no test for its bounds or edge ranges
  evidence: |
    uint32_t mp_rand_in_range32(struct mp_rand_state *s, uint32_t min, uint32_t max)
    {
        mp_assert(min < max);
        uint32_t range = max - min;
        uint32_t mask = mp_round_next_power_of_2(range) - 1;
        uint32_t ret;
        do {
            ret = mp_rand_next(s) & mask;
        } while (ret >= range);
        return min + ret;
    }
  impact: |
    The function has several separate branches, and none of them is tested:
    - `range == 1`: the mask is 0.
    - `range` is an exact power of 2: `mp_round_next_power_of_2` returns `v` unchanged (`common/common.c:422`), so `mask == range-1` and no value is rejected.
    - `range` is not a power of 2: the rejection loop runs.
    - `range > 2^31`, for example `min=0, max=UINT32_MAX`: `mp_round_next_power_of_2` returns 0 (`common/common.c:417,425`), and the code relies on `0 - 1` wrapping to `UINT32_MAX`.
    - `min > 0`: the result is offset by `min`.
    An off-by-one in the mask or offset, or a change to the helper's behavior at 0 or wrap-around, would let out-of-range values through without any test failing. `playlist_shuffle` would then index past `pl->entries`.
  remedy: |
    Add a `test/random.c` executable linked with `test_utils`. Seed it with a fixed value (`mp_rand_seed(1)`) and loop about 10k times over these (min,max) pairs, asserting `min <= r && r < max` each time: (0,1), (5,6), (0,8), (3,11), (0,7), (0,UINT32_MAX), (UINT32_MAX-1,UINT32_MAX). For (0,1) and (5,6), also assert that `r == min` exactly. For a small range such as (0,4), count the results in buckets and assert that every value appears, which catches a mask that is too narrow.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Medium
  category: tests.coverage
  file: misc/random.c
  line: 44
  title: PRNG refactor to caller-held state has no fixed-seed test for the seeded path
  evidence: |
    struct mp_rand_state mp_rand_seed(uint64_t seed)
    {
        struct mp_rand_state ret = {0};
    ...
        ret.v[0] = seed;
        for (int i = 1; i < 4; i++)
            ret.v[i] = splitmix64(&seed);
        return ret;
    }
  impact: |
    This rewrite moved the global state into a struct and rewrote `mp_rand_next` to work through `s->v`. With a nonzero seed, both functions are now pure and deterministic, but nothing pins their output. A mistake in the move, such as a wrong state index or a missing update, would still produce numbers that look random, and no test would notice. `mp_rand_next_double`'s [0.0, 1.0) contract is also unchecked.
  remedy: |
    In the same test file:
    - Call `mp_rand_seed(12345)` twice and assert that both states produce identical `mp_rand_next` sequences.
    - Assert that two different seeds produce different sequences.
    - Record the first 3 to 4 `mp_rand_next` values for one fixed seed as constants, so any change to the algorithm is caught.
    - Assert `0.0 <= d && d < 1.0` over many `mp_rand_next_double` calls.
    Guard the fixed-constant check with `#ifndef FUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION`, because that build forces `seed = 42`.
  confidence: high
  overlap_hints: []

- severity: Low
  category: tests.coverage
  file: common/playlist.c
  line: 176
  title: playlist_shuffle swap-index change has no test that the result is still a permutation
  evidence: |
    size_t j = mp_rand_in_range32(&s, n, pl->num_entries);
    MPSWAP(struct playlist_entry *, pl->entries[n], pl->entries[j]);
  impact: |
    Before this change, `j` was an offset from `n` and the code swapped with `entries[n + j]`. Now `j` is an absolute index and the code swaps with `entries[j]`. A regression in either direction, such as reintroducing `n + j`, would read past the end of the array or skip positions, and nothing would catch it. A test does not need to control the random seed, which is fixed inside the function by `mp_rand_seed(0)`: the invariants it checks hold for any seed.
  remedy: |
    Add a test (it would also need `common/playlist.c` in `test_utils_files`) that builds playlists of size 0, 1, 2, and 50, calls `playlist_shuffle`, and asserts that:
    - every original entry pointer appears exactly once;
    - `pl_index` matches each entry's position, per `playlist_update_indexes`;
    - `original_index` values are a permutation of 0..n-1;
    - `playlist_unshuffle` restores the original order.
  confidence: medium
  overlap_hints: [correctness.logic]

## Files examined
examined: [common/playlist.c, misc/io_utils.c, misc/random.c, misc/random.h, player/main.c]
not_examined: []
