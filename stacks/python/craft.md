# Stack pack: python — craft
extends: core/skills/craft/SKILL.md

## Stack-specific signals
- `Any` / missing type hints at function or API boundaries; casts that obscure the real shape.
- A `utils.py` / `helpers.py` dumping ground or a module crossing ~1000 lines.
- Repeated `isinstance(x, A) ... elif isinstance(x, B)` chains → a missing dataclass / `singledispatch` / protocol.
- Long `**kwargs`-typed blobs where a typed model (`dataclass` / Pydantic / TypedDict) would make the contract explicit.
- Copy-pasted logic that an existing helper (in the repo or stdlib) already covers (`itertools`, `functools`, `collections`).

## Stack-specific remedies
- Add precise type hints at boundaries (`Protocol`, `dataclass`, `TypedDict`); narrow `Any` to a real type.
- Split god modules by responsibility; extract a named abstraction for the isinstance chain.
- Reuse stdlib/repo helpers instead of reinventing.

## Stack-specific severity guidance
- Pervasive `Any` at an API boundary: Medium (type-boundary cleanliness).
- isinstance-chain / god-module that blocks a clear code-judo move: High.
