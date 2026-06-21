# Stack pack: react-native — frontend
extends: core/skills/frontend/SKILL.md

## Stack-specific signals
- `StyleSheet` objects recreated inline on every render (`style={{...}}` or `StyleSheet.create` called in render) instead of hoisted module-scope styles.
- State held in a leaf component that the navigator/siblings need → should live in a global store (Redux/Zustand/Context) or the screen.
- Hardcoded user-facing strings instead of i18n (`react-i18next` / `formatjs`); platform-specific branches duplicating logic (`Platform.OS === 'ios'` repeated everywhere).
- Business/fetch logic inside a component instead of a hook/service; prop drilling across deep navigator trees.
- Mixing navigation libraries or nesting navigators incorrectly; passing non-serializable params to `navigation.navigate`.

## Stack-specific remedies
- Hoist `StyleSheet.create` to module scope; lift shared state to a store/screen; route strings through i18n; extract hooks for side effects.

## Stack-specific severity guidance
- Inline `StyleSheet` / per-render allocation causing churn: Medium/High.
- State stranded in a leaf component needed by the navigator: High.
