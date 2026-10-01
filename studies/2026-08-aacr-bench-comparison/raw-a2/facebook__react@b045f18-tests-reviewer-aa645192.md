<!-- facebook__react@b045f18 tests-reviewer; verbatim final answer -->
## Tests findings

- severity: Medium
  category: tests.coverage
  file: packages/react-devtools-shared/src/backend/fiber/renderer.js
  line: 1491
  title: No DevTools test checks that the new Activity fiber is hidden and its children still show
  evidence: |
    import {ActivityComponent} from 'react-reconciler/src/ReactWorkTags';
    ...
          case HostPortal:
          case HostText:
          case ActivityComponent:
          case LegacyHiddenComponent:
          case OffscreenComponent:
          case Throw:
            return true;
  impact: Every `<Activity>` now creates an extra fiber with tag 31, and DevTools has to hide it. No DevTools test renders `unstable_Activity`. A search of `packages/react-devtools-shared/src/__tests__` finds only "Offscreen" lane labels in `preprocessData-test.js` and `TimelineProfiler-test.js`. Two regressions would go unnoticed: the Activity wrapper showing up in the component tree, or its children being dropped. The filter also uses the tag constant imported from the reconciler instead of the per-version `ReactTypeOfWork` map, and no test pins that choice. The new `case ActivityComponent: return 'Activity'` branch in `getDisplayNameForFiber` (line 631) is also never run by any test.
  remedy: Add a `store-test.js` case gated on `enableActivity`. Render `<Activity mode="visible"><Child /></Activity>` and assert the store snapshot shows `<Child>` directly under its parent, with no Activity or Offscreen element. Add a second case with `mode="hidden"` to pin how hidden children are handled.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Low
  category: tests.coverage
  file: packages/react-reconciler/src/ReactFiberBeginWork.js
  line: 904
  title: No test covers the ref being copied to the Offscreen child when the ref changes on an update
  evidence: |
        const primaryChildFragment = updateWorkInProgressOffscreenFiber(
          currentChild,
          offscreenChildProps,
        );

        primaryChildFragment.ref = workInProgress.ref;
  impact: Ref tests in `Activity-test.js` only check the mount path. Examples are lines 1585, 1906, 1957 and 2074, which assert `offscreenRef.current` / `offscreenRef` is non-null after the first render and then call `detach()`/`attach()`. No test re-renders with a different ref, or with the ref removed, and none checks that the ref is nulled on unmount. The `root.render(null)` at line 2043 asserts only effect logs. If the update branch stopped copying `workInProgress.ref`, the old ref would stay attached and the new one would never be set, and no test would fail.
  remedy: In `Activity-test.js`, render `<Activity mode="manual" ref={refA}>`, then re-render with `ref={refB}`. Assert `refA.current === null` and that `refB.current` has `attach`/`detach`. Then render `null` and assert `refB.current === null`.
  confidence: medium
  overlap_hints: [correctness.logic]

- severity: Low
  category: tests.coverage
  file: packages/shared/isValidElementType.js
  line: 54
  title: No direct test checks that the new Activity symbol counts as a valid element type
  evidence: |
        (enableLegacyHidden && type === REACT_LEGACY_HIDDEN_TYPE) ||
        type === REACT_ACTIVITY_TYPE ||
        type === REACT_OFFSCREEN_TYPE ||
  impact: `unstable_Activity` is now `Symbol.for('react.activity')` instead of the offscreen symbol, so this line is the only reason it still passes validation. `ReactIs-test.js` (lines 61-79 and 166-193) covers Fragment, StrictMode, Suspense, SuspenseList and Profiler but not Activity. Today the line is only exercised indirectly: by the `!enableOwnerStacks` JSX validation at `ReactJSXElement.js:453`/`643` and by `ReactMemo.js:19`. Under owner-stack configs nothing checks it at all.
  remedy: In `ReactIs-test.js`, add a case gated on `enableActivity`: `expect(ReactIs.isValidElementType(React.unstable_Activity)).toBe(true)`. Optionally also assert `React.unstable_Activity === Symbol.for('react.activity')` to pin the public symbol change.
  confidence: high
  overlap_hints: [api-contract.compat]

Two other areas are already covered:
- **Fizz:** the `REACT_ACTIVITY_TYPE` path is exercised by `ReactDOMServerPartialHydration-test.internal.js:3677` (visible) and `:3713` (hidden).
- **Hidden-subtree refs:** handled by `ReactFreshIntegration-test.js:383`.

No existing test asserts the "Activity" name from `getComponentNameFromFiber` or a fiber-tree shape that the extra wrapper would break.

## Files examined
examined: [packages/react-devtools-shared/src/backend/fiber/renderer.js, packages/react-devtools-shared/src/backend/types.js, packages/react-reconciler/src/ReactFiber.js, packages/react-reconciler/src/ReactFiberBeginWork.js, packages/react-reconciler/src/ReactFiberCompleteWork.js, packages/react-reconciler/src/ReactWorkTags.js, packages/react-reconciler/src/getComponentNameFromFiber.js, packages/react-server/src/ReactFizzServer.js, packages/react/src/ReactClient.js, packages/shared/ReactSymbols.js, packages/shared/isValidElementType.js]
not_examined: []
