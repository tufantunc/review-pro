# Infrastructure failures (logged per the registration)

The registration's rule, from "First scored run counts" and Amendment 2 item 12:
- an instance that cannot be prepared is an infrastructure failure for both arms;
- it is logged here with its reason;
- it is never reviewed, and never replaced by re-sampling.

Three of the 30 sampled instances failed before the smoke run, and no arm reviewed any of them.

| # | Instance | References (context) | Reason |
|---:|---|---|---|
| 5 | `astral-sh__uv@ed57db2` | 6 (File 4, Repo 2) | The benchmark's head commit no longer exists on GitHub |
| 13 | `comfyanonymous__ComfyUI@cfc3122` | 6 (File 6) | The benchmark's head commit no longer exists on GitHub |
| 19 | `ClickHouse__ClickHouse@5fb6ee3` | 11 (Diff 5, File 5, Repo 1) | The repository's history could not be downloaded |

## #5 and #13: head commits gone from GitHub

The benchmark pins each instance to a head commit. For these two, that commit cannot be fetched
from GitHub by any route (checked 2026-09-28).

**The fetch fails.** `git fetch origin <sha>` returns `upload-pack: not our ref`, for
`ed57db2b34c2a7a955b2dc76583dce7ace02e628` and for `cfc312296c0b9f255bba6b4b2789ac7bbc66a7cb`.

**The commits API does not know them either.** Both shas return
`No commit found for SHA ... (HTTP 422)`.

**The PR heads moved after the benchmark was built.** Both PRs are merged, and their current heads
are other commits:

| PR | Current head | Merged |
|---|---|---|
| `astral-sh/uv#11088` | `75baf506d709` | 2025-01-31 |
| `comfyanonymous/ComfyUI#9560` | `efd299d68149` | 2025-09-05 |

The recorded commits were, most likely, force-pushed away. Reviewing either instance at another
commit would change the code under review, so neither is reviewed.

## #19: ClickHouse history not obtainable

ClickHouse is about 12.6 GB (GitHub's size figure) and has about 293,000 commits on `master`. The
isolated instance repository of Amendment 2 item 5 needs the full history reachable from head and
base. Without it there is no merge base, and item 12's check fails; a shallow repository would
also give the arms less than every other instance gets.

On this host, every transfer from `github.com` for this one repository broke after roughly 75 to
80 minutes, or about 2 to 4 GB, with `early EOF` / `invalid index-pack output`. Other large
repositories cloned in one piece over the same connection, FreeCAD among them in 3.2 hours.

Attempts, 2026-09-28 to 2026-09-30, all over HTTPS; this host has no SSH access to GitHub:

| Strategy | Attempts | Outcome |
|---|---|---|
| Plain full clone | 4 | each broke mid-transfer |
| Shallow clone of all branch tips (1.55 GB, succeeded), then `--deepen=20000` | 4 | each broke after 3.3 to 3.9 GB |
| The same, `--deepen=15000` on `master` | 13 | each broke after 4,524 to 4,862 s |
| Fresh single-branch, tag-less, depth-1 clone of `master` (succeeded), then deepening with adaptive chunks (2,000 commits halved to 200) and a 65-minute guard | 24 | every chunk failed or hit the guard. A 200-commit deepen still transferred over 2 GB before the guard, consistent with git re-sending objects when deepening a shallow clone |

These alternatives were considered and not used:
- **A ZIP snapshot:** it carries no history.
- **Two synthetic commits built from two snapshots:** that would review this one instance under
  conditions no other instance has, contrary to item 5.
- **The `gh` CLI:** it uses the same git-over-HTTPS transport; the repository is public, so the
  transfer is the same.

The maintainer decided on 2026-09-30 to record #19 as an infrastructure failure.

## Consequences, stated before any review

| | Before | After |
|---|---|---|
| Scorable instances | 30 | 27 |
| References | 190 | 167 |
| Diff / File / Repo references | 84 / 82 / 24 | 79 / 67 / 21 |
| Primary test (instances with a repo-context reference) | at most 14 | at most **12**, over **21** repo references |

- **Primary test:** #5 and #19 each had repo-context references.
- **Remaining instances:** they keep the seed's order. A later partial run truncates that order
  from the top, skipping these three.
- **These are not reviewed:** the smoke run's instances 1 to 5 include #5, which is recorded
  here and not reviewed.
