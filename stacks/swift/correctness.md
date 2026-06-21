# Stack pack: swift — correctness
extends: core/skills/correctness/SKILL.md

## Stack-specific signals
- Force-unwrap `!` / force-try `try!` on a nil/throwing value that can realistically fail (JSON parse, downcast, optional chain, Core Data fetch) → runtime crash.
- **Retain cycle**: `self` captured strongly in a closure stored on `self` (`@escaping` closure, delegate, Timer, Combine subscription) without `[weak self]`.
- SwiftUI: side effects / network in `body`; heavy work in computed properties re-run every render; mutating state during `body`.
- `DispatchQueue.main.async` assumed ordering; race on shared mutable state across queues without `actor`/`DispatchQueue`/lock.
- async/await: unhandled `Error` (no `try`/`catch`), or calling `Task.detached`/`Task { }` without structured cancellation → leaks.
- `Date()`/`UUID()` computed during view body → changes every render; index out of bounds on `Array` without bounds check.

## Stack-specific remedies
- Use `guard let`/optional chaining; capture `[weak self]`; do side effects in `.task`/`.onAppear`/`@StateObject`; use `actor`/`@MainActor` for shared state; bound `Task` lifetime.

## Stack-specific severity guidance
- Force-unwrap/force-try on real input / retain cycle: High.
- Side effect or `Date()` inside SwiftUI `body`: Medium/High.
