<!-- facebook__react@b045f18 api-contract-reviewer; verbatim final answer -->
## API-Contract findings

- severity: Medium
  category: api-contract.schema
  file: packages/react-devtools-shared/src/backend/fiber/renderer.js
  line: 149
  title: DevTools reads ActivityComponent from the reconciler's current tag number instead of the version-keyed WorkTagMap
  evidence: |
    import {ActivityComponent} from 'react-reconciler/src/ReactWorkTags';
    ...
      ViewTransitionComponent: 30, // Experimental
      ActivityComponent: 31,
    ...
      Throw,
      ViewTransitionComponent,
    } = ReactTypeOfWork;          // ActivityComponent is not destructured
    ...
    switch (tag) {
      case ActivityComponent:
        return 'Activity';
    ...
      case HostText:
      case ActivityComponent:
      case LegacyHiddenComponent:
  impact: The DevTools backend works with many React versions. `getInternalReactConstants(version)` exists so that each tag number is looked up per version, and the file says so at line 348-349: "Keep it in sync, and add version guards if it changes." This change adds `ActivityComponent` to `WorkTagMap` (types.js:80) and fills it in every version branch (31 for the newest, -1 for older ones). But neither destructuring reads it: not the one at renderer.js:554-581 (inside `getInternalReactConstants`) and not the one at :899-928 (inside `attach`). So `getDisplayNameForFiber` (:631) and `shouldFilterFiber` (:1491) both use the constant 31 imported from the reconciler, whatever version is attached, and the new map entry is never read. This is also the first runtime value import from `react-reconciler/src` in react-devtools-shared/src/backend; every other reconciler import there is `import type`. Nothing breaks today. The older branches I read stop below 31, so no attached version gives 31 a different meaning, and the `-1` entries are never consulted. The cost is that the version guard for this tag is gone: if 31 is ever renumbered or reused, DevTools will name and filter the wrong fibers for that version with no warning, and the `-1` values give a false sense that this was handled.
  remedy: Remove the import from `react-reconciler/src/ReactWorkTags`. Add `ActivityComponent` to both destructurings of `ReactTypeOfWork`, at :554-581 and :899-928, as is done for `ViewTransitionComponent`. Optionally mark the newest-branch entry `// Experimental` to match its neighbours.
  confidence: high
  evidence_refs: [packages/react-devtools-shared/src/backend/fiber/renderer.js:389, packages/react-devtools-shared/src/backend/fiber/renderer.js:554, packages/react-devtools-shared/src/backend/fiber/renderer.js:921, packages/react-devtools-shared/src/backend/fiber/renderer.js:1491, packages/react-devtools-shared/src/backend/types.js:80]
  overlap_hints: [craft.boundary, correctness.cross-file]

- severity: Nitpick
  category: api-contract.types
  file: packages/react-reconciler/src/ReactFiber.js
  line: 882
  title: Activity got its own element type and tag but still uses OffscreenProps, so the internal-only mode is part of its typed contract
  evidence: |
    export function createFiberFromActivity(
      pendingProps: OffscreenProps,
  impact: `OffscreenProps.mode` (ReactFiberActivityComponent.js:20) includes the internal value `'unstable-defer-without-hiding'`. `updateActivityComponent` (ReactFiberBeginWork.js:871-908) passes `nextProps.mode` straight through to the inner Offscreen fiber. So the public `<Activity>` still accepts the internal mode at the type level, and at runtime too. This is not a regression: before this change `unstable_Activity` simply was the Offscreen type. But a change meant to give Activity a separate identity left its props contract unseparated.
  remedy: Add an `ActivityProps` type limited to `mode?: 'hidden' | 'visible' | null` plus `children`, and use it in `createFiberFromActivity`. Map it to `OffscreenProps` explicitly in `updateActivityComponent`.
  confidence: medium
  evidence_refs: [packages/react-reconciler/src/ReactFiberActivityComponent.js:20, packages/react-reconciler/src/ReactFiberBeginWork.js:871]
  overlap_hints: [craft.types]

Answers to the questions in the prompt, from the code. None of these is a finding.
- **Mixing versions after the symbol swap.** A newer `react` with an older `react-dom` or `react-native-renderer` is rejected at startup by the exact-version checks in `packages/react-dom/src/shared/ensureCorrectIsomorphicReactVersion.js:17` and `packages/react-native-renderer/src/ReactNativeRenderer.js:58`. And `unstable_Activity` is an unstable export in index.js, index.experimental.js, index.fb.js and the development builds.
- **Fizz.** It handles `REACT_ACTIVITY_TYPE` (ReactFizzServer.js:2265).
- **Flight.** It has no case for either symbol; it sends symbol types as references by registered name (`serializeSymbolReference` / `emitSymbolChunk`, ReactFlightServer.js:1932 and :3196), so `react.activity` arrives intact.
- **ReactServer entrypoints.** They don't export `unstable_Activity`.
- **No other dependents of the old symbol.** Nothing else in `packages/` (tests excluded) compares against `Symbol.for('react.offscreen')`.
- **Older gaps, not regressions.** `getComponentNameFromType`, react-is, and react-test-renderer's `toTree` handled neither the Offscreen symbol nor its tag before this change.

## Files examined
examined: [packages/react-devtools-shared/src/backend/fiber/renderer.js, packages/react-devtools-shared/src/backend/types.js, packages/react-reconciler/src/ReactFiber.js, packages/react-reconciler/src/ReactFiberBeginWork.js, packages/react-reconciler/src/ReactFiberCompleteWork.js, packages/react-reconciler/src/ReactWorkTags.js, packages/react-reconciler/src/getComponentNameFromFiber.js, packages/react-server/src/ReactFizzServer.js, packages/react/src/ReactClient.js, packages/shared/ReactSymbols.js, packages/shared/isValidElementType.js]
not_examined: []

Note on coverage: for every file listed I read the diff hunks. Of renderer.js, the only parts I read beyond the diff were lines 345-359, 548-637 and 1470-1619, and I located the second destructuring (:899-928) only by grep. For the other files I read only the diff and nearby lines found by grep, not the full contents.
