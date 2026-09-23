# Stack pack: rust — security
extends: core/skills/security/SKILL.md

## Stack-specific signals
- `unsafe { ... }` introduced without a documented safety invariant, or wrapping unchecked FFI (`std::ptr`, `from_raw_parts`, `transmute`) on untrusted input → memory unsafety (the one thing Rust exists to prevent).
- `serde_json::from_str` / `bincode` / `rmp-serde` deserializing attacker-controlled bytes into types with custom `Deserialize` that touches I/O/secrets → deserialization issues.
- SQL built with `format!`/`format_args!` for `sqlx::query` / `diesel` instead of bind parameters (`query!` macros, `?`/`$1`) → SQL injection.
- `Command::new("sh").arg("-c").arg(user_input)` / `Command::new(user_input)` → command injection.
- Path built from user input via `format!`/`push` without `Path::canonicalize` + base confinement → path traversal.
- `rand::thread_rng()` / `rand::random()` for tokens, session IDs, or crypto; use `rand::rngs::OsRng` / `getrandom`.
- `rustls`/`reqwest` with `danger_accept_invalid_certs(true)` / `accept_invalid_hostnames`.

## Stack-specific remedies
- Avoid `unsafe`; if unavoidable, write a `// SAFETY:` comment justifying the invariant.
- Bind SQL params; arg-array `Command`; confine + canonicalize paths; `OsRng` for secrets; never disable cert validation.

## Stack-specific severity guidance
- `unsafe` on untrusted input / `transmute` / string-built SQL: Critical/High.
- `OsRng` skipped for a token, `danger_accept_invalid_certs`: High.

## Not a finding
- `sqlx::query!` and `query_as!` with `$1`/`?` placeholders, `.bind(value)`, and Diesel's query builder: values are bound, not spliced.
- `Command::new("git").arg(user_value)`: arguments go to the program directly, with no shell. Option injection remains when the value can start with `-`.
- `serde_json::from_str` or `bincode` into plain data types. Serde builds only the types the target names, so the payload cannot choose a type to instantiate. This pack's signal is a custom `Deserialize` with side effects, not deserialization in general.
- An `unsafe` block whose `// SAFETY:` comment states an invariant you checked and found to hold at every call site.
