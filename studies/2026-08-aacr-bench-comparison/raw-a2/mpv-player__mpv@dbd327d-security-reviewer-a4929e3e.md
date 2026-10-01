<!-- mpv-player__mpv@dbd327d security-reviewer; verbatim final answer -->
## Security findings: none

I found no security issues in the added or modified code. What I checked:

- **Temp file names (`misc/io_utils.c`).** `mp_mkostemps` calls `open(template, O_RDWR | O_CREAT | O_EXCL | flags, 0600)`. With `O_EXCL`, an existing file or symlink at the chosen path returns `EEXIST` and the loop picks another name. So a guessable name doesn't let a local attacker redirect or pre-create the write. It only costs a retry. The change also makes the name harder to guess than before: each call now seeds its own state from `av_random_bytes()`, where before one global state was seeded once at startup.
- **Seeding (`misc/random.c`).** The full 256-bit state now comes from `av_random_bytes()`, which is stronger than the old 64-bit seed expanded with splitmix64. The fallback path (`mp_raw_time_ns() ^ &mp_rand_seed + &ret`) runs only when `av_random_bytes()` fails. In theory the PRNG outputs could be inverted to recover a mix of time and ASLR addresses. In practice the only visible outputs are 6 hex characters of a temp file name and the shuffle order, and time and the two addresses are combined together, so no usable address leaks. I did not file this.
- **`mp_rand_in_range32` / `playlist_shuffle`.** This is a non-cryptographic generator used for shuffle order, which the skill lists as not a vulnerability. Shuffle indices stay inside `[n, num_entries)`, so the swap can't go out of bounds. One edge case: if `range` exceeds 2^31, `mp_round_next_power_of_2` returns 0 and the mask becomes `0xFFFFFFFF`. That is still correct, because values at or above `range` are rejected and redrawn. No memory-safety problem.
- **Thread safety.** Removing the mutex is safe. Every caller (`common/playlist.c:173`, `misc/io_utils.c:43`) now holds its own state on the stack, and no other callers exist in the repo.
- **`player/main.c`.** The removed global seed call has nothing security-relevant left depending on it.

## Files examined
examined: [common/playlist.c, misc/io_utils.c, misc/random.c, misc/random.h, player/main.c]
not_examined: []
