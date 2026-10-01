<!-- facebook__react@b045f18 correctness-reviewer; verbatim final answer -->
- severity: Low
  category: correctness.side-effect
  file: packages/react-devtools-shared/src/backend/fiber/renderer.js
  line: 149
  title: DevTools checks ActivityComponent against the monorepo's tag number, not the tag map for the inspected React version
  evidence: |
    import {ActivityComponent} from 'react-reconciler/src/ReactWorkTags';
    ...
          ActivityComponent: -1, // Doesn't exist yet
    ...
      } = ReactTypeOfWork;   // destructure (lines 560-581 and 904-928) omits ActivityComponent
    ...
        switch (tag) {
          case ActivityComponent:
            return 'Activity';
    ...
          case HostText:
          case ActivityComponent:
          case LegacyHiddenComponent:
  evidence_refs: [packages/react-devtools-shared/src/backend/fiber/renderer.js:389, packages/react-devtools-shared/src/backend/fiber/renderer.js:426, packages/react-devtools-shared/src/backend/fiber/renderer.js:581, packages/react-devtools-shared/src/backend/fiber/renderer.js:631, packages/react-devtools-shared/src/backend/fiber/renderer.js:928, packages/react-devtools-shared/src/backend/fiber/renderer.js:1491]
  impact: |
    The rest of `getDisplayNameForFiber` and `shouldFilterFiber` uses tags pulled from the `ReactTypeOfWork` map for the inspected React version. That map is how DevTools copes with React versions that number the same tag differently; for example, OffscreenComponent is 22 in the newest map and 23 in the 17.0.0-alpha map. `ActivityComponent` is the one exception: both switches use the constant 31 imported from the monorepo, whatever React version is being inspected. As a result, the `ActivityComponent: -1` entries this change adds to the older maps (lines 426, 463, 500, 537) have no effect, and the `ActivityComponent: 31` entry in the newest map is never read. Today no supported React version uses tag 31 for anything else, so I found no misclassification right now. But if a later React release gives a different tag to Activity, or reuses 31, DevTools will hide or misname fibers for that version, and editing the per-version map will not fix it. This is the first runtime import from `react-reconciler` into the DevTools backend (other imports are type-only). It resolves only through the yarn workspace link: the devtools Jest mapper `^react-reconciler/([^/]+)$` does not match the two-segment path `src/ReactWorkTags`.
  remedy: Remove the import. Add `ActivityComponent` to both `ReactTypeOfWork` destructures (inside `getInternalReactConstants` and inside `attach`) so the version-specific value is used, as every other tag already is.
  confidence: high
  overlap_hints: [craft.layering, api-contract.back-compat]

Other paths I checked and found correct (no findings):
- **Ref forwarding:** `coerceRef` puts the ref on the Activity fiber. `updateActivityComponent` copies it to the Offscreen child, and the child's `markRef` attaches it to `OffscreenInstance` through `commitAttachRef`'s default case, the same as before. The Activity fiber never gets the Ref flag, so the ref is not attached twice.
- **Lanes and bailouts:** a deferred hidden Offscreen sets `lanes`/`childLanes` to OffscreenLane. `completeWork` for ActivityComponent calls `bubbleProperties`, so the parent picks this up. The default path in `attemptEarlyBailoutIfNoUpdate`, then `bailoutOnAlreadyFinishedWork`, then `cloneChildFibers`, still reaches the Offscreen child at OffscreenLane.
- **Offscreen created with NoLanes:** this matches how Suspense creates its Offscreen child.
- **Commit, Suspense and hidden-subtree logic:** `ReactFiberCommitWork.js:975`, `:4271` and `ReactFiberConcurrentUpdates.js:236` key off the Offscreen fiber, which still exists. The `return.tag === SuspenseComponent` checks give the same result as before.
- **Fizz:** `REACT_ACTIVITY_TYPE` goes through `renderOffscreen` with the same keyPath, so server output and useId behave the same.
- **Behavior unchanged from before:** `shared/getComponentNameFromType`, `ReactFiberComponentStack`, DevTools component stacks and react-test-renderer `toTree` had no Offscreen or Activity handling before either. `isValidElementType` stays ungated, just as `REACT_OFFSCREEN_TYPE` was.

## Files examined
examined: [packages/react-devtools-shared/src/backend/fiber/renderer.js, packages/react-devtools-shared/src/backend/types.js, packages/react-reconciler/src/ReactFiber.js, packages/react-reconciler/src/ReactFiberBeginWork.js, packages/react-reconciler/src/ReactFiberCompleteWork.js, packages/react-reconciler/src/ReactWorkTags.js, packages/react-reconciler/src/getComponentNameFromFiber.js, packages/react-server/src/ReactFizzServer.js, packages/react/src/ReactClient.js, packages/shared/ReactSymbols.js, packages/shared/isValidElementType.js]
not_examined: []
