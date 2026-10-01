<!-- facebook__react@b045f18 ai-antipatterns-reviewer; verbatim final answer -->
## AI-Antipatterns findings

- severity: Medium
  category: ai-antipatterns.ignored-convention
  file: packages/react-devtools-shared/src/backend/fiber/renderer.js
  line: 149
  title: DevTools backend imports a runtime work-tag value from react-reconciler instead of reading it from the version-keyed ReactTypeOfWork map, so the new `ActivityComponent: 31` entry is never read
  evidence: |
    import {ActivityComponent} from 'react-reconciler/src/ReactWorkTags';
    ...
          ViewTransitionComponent: 30, // Experimental
          ActivityComponent: 31,
    ...
        ViewTransitionComponent,
      } = ReactTypeOfWork;          // line 581: ActivityComponent not destructured
    ...
          case ActivityComponent:     // line 631, resolves to the imported constant
            return 'Activity';
    ...
          case ActivityComponent:     // line 1491, shouldFilterFiber
  impact: |
    Assumed: importing the tag from the reconciler is equivalent to the map. Actual: this is the only runtime (non-`import type`) import from `react-reconciler` anywhere in react-devtools-shared/src. A grep for `from 'react-reconciler'` without `import type` returns just line 149. Every other tag (ViewTransitionComponent, Throw, OffscreenComponent, ...) is destructured from `ReactTypeOfWork` at lines 560-581 and 899-928, so the attached React version decides the tag.
    The change adds `ActivityComponent: 31` and four `-1 // Doesn't exist yet` entries to that map (lines 389, 426, 463, 500, 537), but nothing reads them. Both `case ActivityComponent:` sites use the hard-coded 31 from the reconciler source, whatever React version is attached. That defeats the per-version abstraction, ties the DevTools backend build to reconciler source, and leaves the map entries dead.
  remedy: Delete the import at line 149. Add `ActivityComponent` to the `ReactTypeOfWork` destructuring blocks at lines ~560-581 (getInternalReactConstants) and ~899-928 (attach), the same way `ViewTransitionComponent` is handled. Optionally add `// Experimental` to the 18.x map entry to match its neighbour.
  confidence: high
  evidence_refs: [packages/react-devtools-shared/src/backend/fiber/renderer.js:389, packages/react-devtools-shared/src/backend/fiber/renderer.js:581, packages/react-devtools-shared/src/backend/fiber/renderer.js:631, packages/react-devtools-shared/src/backend/fiber/renderer.js:1491, packages/react-devtools-shared/src/backend/fiber/renderer.js:928]
  overlap_hints: [correctness.cross-file, craft.boundary]

- severity: Low
  category: ai-antipatterns.ignored-convention
  file: packages/react-reconciler/src/ReactFiberBeginWork.js
  line: 885
  title: updateActivityComponent copies Suspense naming (`primaryChildFragment`) and repeats the same child-wiring tail in both branches
  evidence: |
      if (current === null) {
        const primaryChildFragment = mountWorkInProgressOffscreenFiber(
          offscreenChildProps,
          mode,
          renderLanes,
        );
        primaryChildFragment.ref = workInProgress.ref;
        workInProgress.child = primaryChildFragment;
        primaryChildFragment.return = workInProgress;

        return primaryChildFragment;
      } else {
        ...
        primaryChildFragment.ref = workInProgress.ref;
        workInProgress.child = primaryChildFragment;
        primaryChildFragment.return = workInProgress;
        return primaryChildFragment;
      }
  impact: |
    The child is an Offscreen fiber. Nothing about it is a "primary child fragment": that name and shape come from the Suspense helpers (mountSuspensePrimaryChildren and nearby, ~line 2337), which really do have primary and fallback fragments. The memo-component precedent in this same file (lines 538-542 and 563-566) uses a neutral `child`/`newChild` name and does the ref/return/child wiring once per path.
    The pasted name and the duplicated three-line tail suggest a Suspense pattern copied without adapting it. `renderLanes` is used: it goes to `mountWorkInProgressOffscreenFiber`, which ignores it (existing code at line 2422-2430), so no unused-parameter finding.
  remedy: Compute `const child = current === null ? mountWorkInProgressOffscreenFiber(offscreenChildProps, mode, renderLanes) : updateWorkInProgressOffscreenFiber((current.child: any), offscreenChildProps);`, then do the `ref`/`return`/`workInProgress.child` assignments once and `return child`.
  confidence: medium
  evidence_refs: [packages/react-reconciler/src/ReactFiberBeginWork.js:540, packages/react-reconciler/src/ReactFiberBeginWork.js:564, packages/react-reconciler/src/ReactFiberBeginWork.js:2422]
  overlap_hints: [dry.duplication, craft.readability]

Checked and not flagged:
- `createFiberFromActivity` typed as `OffscreenProps`: this follows the existing `createFiberFromLegacyHidden(pendingProps: OffscreenProps, ...)` at ReactFiber.js:911-912, and no `ActivityProps` type exists in the repo.
- Removing `REACT_OFFSCREEN_TYPE` from ReactClient.js: it has no other uses in that file.
- `REACT_ACTIVITY_TYPE` falling through to `renderOffscreen` in Fizz, the new `isValidElementType` clause, and the CompleteWork `bubbleProperties` fallthrough: all match existing patterns. No invented symbols or dependencies.

## Files examined
examined: [packages/react-devtools-shared/src/backend/fiber/renderer.js, packages/react-devtools-shared/src/backend/types.js, packages/react-reconciler/src/ReactFiber.js, packages/react-reconciler/src/ReactFiberBeginWork.js, packages/react-reconciler/src/ReactFiberCompleteWork.js, packages/react-reconciler/src/ReactWorkTags.js, packages/react-reconciler/src/getComponentNameFromFiber.js, packages/react-server/src/ReactFizzServer.js, packages/react/src/ReactClient.js, packages/shared/ReactSymbols.js, packages/shared/isValidElementType.js]
not_examined: []
