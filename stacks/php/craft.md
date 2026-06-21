# Stack pack: php — craft
extends: core/skills/craft/SKILL.md

## Stack-specific signals
- A god class / huge `class Foo` controller or service crossing ~1000 lines, mixing data access + business rules + rendering.
- Missing parameter/return type declarations (`function foo($x)` with no `: int`/`array`/DTO) at boundaries; `mixed`/no types where a precise shape exists.
- Spaghetti of `include`/`require` chains instead of autoloading (PSR-4) + classes.
- Repeated inline array/HTML snippets that should be a typed value object / template partial.
- Copy-pasted helpers (validation, date formatting) that the codebase/stdlib already has.
- Configuration / credentials / SQL / HTML mixed into business logic.

## Stack-specific remedies
- Add strict types + parameter/return declarations at boundaries; PSR-4 autoload; extract focused services; reuse canonical helpers.

## Stack-specific severity guidance
- God class blocking a clear code-judo split: High.
- Pervasive missing types at an API boundary: Medium (type-boundary cleanliness).
