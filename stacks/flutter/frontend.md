# Stack pack: flutter — frontend
extends: core/skills/frontend/SKILL.md

## Stack-specific signals
- `setState` inside `build`, or business logic / network calls fired from `build` → rebuild storms + side effects.
- State held in `StatefulWidget` fields that belongs in a provider (Provider/Riverpod/Bloc) when it's needed higher up or shared.
- Widget tree bloat: a huge `build` method that should be extracted into named widgets; deep nesting that can't be scanned.
- Missing `const` constructors on widgets that could be constant → extra allocations + loses build-cache benefits.
- Hardcoded user-facing strings instead of `AppLocalizations` (l10n).
- Business/data logic inside the widget layer instead of a repository/controller.

## Stack-specific remedies
- Move non-trivial state to a provider/bloc; trigger side effects from event handlers, not `build`.
- Extract focused widgets; add `const` where possible; route user strings through `AppLocalizations`.

## Stack-specific severity guidance
- `setState`/side-effects in `build`: High.
- State stranded in a leaf widget needed elsewhere: High.
- Missing `const`/extracted widget (structure): Medium.
