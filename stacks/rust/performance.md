# Stack pack: rust — performance
extends: core/skills/performance/SKILL.md

## Stack-specific signals
- Unnecessary `.clone()` of `String`/`Vec`/`Arc` where a borrow (`&str`, `&[T]`) or `Cow` would do — especially in a hot loop.
- Repeated `String` allocation (`format!`, `to_string`) in a loop instead of `write!` to a `String`/`fmt::Write`.
- `Vec`/`HashMap` grown by repeated `push`/`insert` when capacity is known → `Vec::with_capacity` / `HashMap::with_capacity`.
- O(n²) lookup (`Vec::contains`/`.iter().find`) where a `HashSet`/`HashMap` fits.
- Blocking the async runtime with sync CPU/IO work (see backend pack) — also a perf problem.
- Allocating in the hot path of a parser/tight loop when iteration over a slice would do.

## Stack-specific remedies
- Borrow instead of clone; `with_capacity`; replace linear scans with hash sets; offload blocking work.

## Stack-specific severity guidance
- `.clone()` / O(n²) scan in a measured hot loop with realistic data: Medium/High.
- Blocking the async runtime: High (availability).
- Micro-tuning without impact: do not report.
