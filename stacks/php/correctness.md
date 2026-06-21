# Stack pack: php — correctness
extends: core/skills/correctness/SKILL.md

## Stack-specific signals
- Loose comparison `==` where `===` is required: `0 == "foo"` (true pre-8.0), `"" == 0`, `null == false`, `"1" == "01"` → silent logic bugs.
- Undefined variable / undefined array index / null array access producing `E_WARNING`/`E_NOTICE` (or fatal in stricter modes).
- `array_merge` vs `+` confusion (`+` keeps first key; numeric keys renumber in merge).
- `array_search` / `in_array` with loose comparison (`in_array($x, $arr)` matches `true`/non-strict) — pass `strict: true`.
- Division/modulo by zero; integer overflow to float silently.
- `date()`/`strtotime()`/`DateTime` without an explicit timezone (`date_default_timezone_set`/`DateTimeZone`) → server-dependent results.
- `strpos`/`strstr` result compared loosely (`if (strpos(... ))` — `0` is falsy) — use `!== false`.

## Stack-specific remedies
- Use `===`/`!==`; pass `strict` to `in_array`/`array_search`; check array key existence with `isset`/`array_key_exists`; set an explicit timezone.

## Stack-specific severity guidance
- Loose `==`/`in_array` non-strict on an auth/permission/id check: High.
- Undefined-index/`strpos`-truthiness on a real path: Medium/High.
