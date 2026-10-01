<!-- mpv-player__mpv@dbd327d craft-reviewer; verbatim final answer -->
## Craft findings

- severity: Low
  category: craft.code-judo
  file: misc/random.h
  line: 48
  title: mp_rand_next_double() has no callers left and should be deleted
  evidence: |
    /*
     * Return a double value in the range of [0.0, 1.0) with uniform
     * distribution, and update the state accordingly.
     */
    double mp_rand_next_double(struct mp_rand_state *s);
  impact: The only caller was the shuffle in common/playlist.c, and this change moves it to mp_rand_in_range32(). A repo-wide grep for `mp_rand_` now finds this function only in misc/random.c and misc/random.h. Yet the change still rewrites it to take the new state pointer and keeps it in the public header. Nothing uses it, but it still has to be maintained. It is also the float-scaling approach to bounded random numbers, which is slightly biased and which this change deliberately stops using. Leaving it exported invites the next caller to pick it over the unbiased helper.
  remedy: Delete mp_rand_next_double() from misc/random.h and misc/random.c. The module's API then shrinks to seed, next and in_range32, and every bounded draw goes through the one unbiased helper. Add it back only when a real caller needs a double.
  confidence: high
  overlap_hints: [ai-antipatterns.over-engineering]

- severity: Low
  category: craft.boundary
  file: player/main.c
  line: 33
  title: Unused include of misc/random.h left after the mp_rand_seed(0) call was removed
  evidence: |
    #include "misc/random.h"
    ...
    -    mp_time_init();
    -    mp_rand_seed(0);
  impact: This change removes the only use of the random module in player/main.c, so the include now points to a dependency the file no longer has. That hides the fact that the player core no longer owns PRNG setup, and anyone looking for global seeding will be sent to the wrong place. osdep/io.c has the same unused include, but it predates this change.
  remedy: Remove `#include "misc/random.h"` from player/main.c in this change. Optionally remove the old one from osdep/io.c in a separate cleanup.
  confidence: high
  overlap_hints: []

Overall the change is a structural improvement. It removes the global mutex-protected state and makes each caller own its RNG, and the new bounded helper replaces the old float-scaling shuffle while reusing the existing `mp_round_next_power_of_2()` in common/common.c. No size or spaghetti concerns.

## Files examined
examined: [common/playlist.c, misc/io_utils.c, misc/random.c, misc/random.h, player/main.c]
not_examined: []
