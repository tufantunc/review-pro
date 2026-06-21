# Stack pack: python — correctness
extends: core/skills/correctness/SKILL.md

## Stack-specific signals
- Bare `except:` / `except Exception:` that swallows without re-raise or logging → silent failures.
- Mutable default args (`def f(items=[])`) shared across calls.
- Un-awaited coroutine / `async def` called without `await` → never runs.
- `==` for `None` / singletons where `is` is correct; `is` with strings/integers (interning assumption).
- `requests.get(url)` with no `timeout=` → can hang a worker indefinitely.
- Thread/async shared mutable state without a lock (GIL does NOT make compound ops atomic).
- `dict` mutated during iteration; integer/None truthiness bugs (`if items:` vs `if items is not None:`).

## Stack-specific remedies
- Catch specific exceptions; re-raise or log; never swallow `BaseException`.
- Use `None` defaults + `if x is None: x = []`.
- Always `await` coroutines; always pass `timeout=` to network calls.
- Prefer `is None` / `is not None`.

## Stack-specific severity guidance
- `requests` with no timeout on a request-handling path: High.
- Swallowed exception masking a write failure: High.
- Mutable default arg on a mutating function: Medium.
