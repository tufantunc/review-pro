# Stack pack: rust — correctness
extends: core/skills/correctness/SKILL.md

## Stack-specific signals
- `.unwrap()` / `.expect()` on a `Result`/`Option` that can realistically be `Err`/`None` (user input, I/O, parse, lookup) → `panic!` in production.
- `panic!` / `unreachable!` / `todo!` / `unimplemented!` on a reachable path.
- Integer overflow with `as` casts (`u64 as u32`, `i32 as usize`) without bounds checks; `wrapping_*` / `checked_*` misuse.
- Lock-ordering / `std::sync::Mutex` held across `await` (deadlock with async runtimes), or `RwLock` write-guard held too long.
- `.clone()` of a guard / iterating a channel without termination; `mpsc` receiver dropped while senders alive → silent hang.
- Silently swallowed `Result` via `let _ = ...` on a real failure path; `if let Ok(_) = ...` ignoring `Err`.
- Off-by-one in slice/range indexing (`..len` vs `..=`, `split_at` misuse) → panic.
- `String::from_utf8` / `str::from_utf8` unchecked producing invalid UTF-8 assumptions.

## Stack-specific remedies
- `?` + typed errors (`thiserror`/`anyhow`) instead of `unwrap`; bound casts with `try_from`/`checked_*`.
- Never hold a sync lock across `await`; use async-aware locks; handle `Err` explicitly.

## Stack-specific severity guidance
- `unwrap`/`panic` on a reachable input/IO path: High.
- Mutex held across `await` / overflow cast on untrusted data: High.
