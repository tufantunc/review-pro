<!-- facebook__react@b045f18 dry-reviewer; verbatim final answer -->
- severity: Medium
  category: dry.duplication
  file: packages/react-devtools-shared/src/backend/fiber/renderer.js
  line: 149
  title: DevTools has two sources for the ActivityComponent tag; the switches use the reconciler import, not the per-version map
  evidence: |
    import {ActivityComponent} from 'react-reconciler/src/ReactWorkTags';
    ...
          ViewTransitionComponent: 30, // Experimental
          ActivityComponent: 31,
    ...
          case ActivityComponent:
            return 'Activity';
    ...
          case ActivityComponent:
          case LegacyHiddenComponent:
  evidence_refs:
    - packages/react-devtools-shared/src/backend/fiber/renderer.js:389
    - packages/react-devtools-shared/src/backend/fiber/renderer.js:426
    - packages/react-devtools-shared/src/backend/fiber/renderer.js:554-581
    - packages/react-devtools-shared/src/backend/fiber/renderer.js:631
    - packages/react-devtools-shared/src/backend/fiber/renderer.js:902-928
    - packages/react-devtools-shared/src/backend/fiber/renderer.js:1491
  impact: The diff adds `ActivityComponent` to all five `ReactTypeOfWork` version maps and to the `WorkTagMap` type. Neither `const {...} = ReactTypeOfWork` destructure (lines 554-581 in `getInternalReactConstants`, lines 902-928 in `attach`) picks it up, so both `case ActivityComponent:` sites at lines 631 and 1491 use the constant imported from the reconciler. The map entries (31, or -1 for older versions) are never read. This tag is the only one that skips the version map, which is there so DevTools can handle any renderer version. When an older renderer is attached, the tag still matches 31 instead of -1. If the tag number ever changes, two places hold it and they can drift apart.
  remedy: Remove the `react-reconciler/src/ReactWorkTags` import at line 149. Add `ActivityComponent` to both `ReactTypeOfWork` destructures, next to `ViewTransitionComponent` at lines 580 and 927. Every other tag, such as `OffscreenComponent` and `ViewTransitionComponent`, is read this way.
  confidence: high
  overlap_hints: [ai-antipatterns.ignored-convention, correctness]

- severity: Low
  category: dry.copy-paste
  file: packages/react-reconciler/src/ReactFiberBeginWork.js
  line: 885
  title: Both branches of updateActivityComponent repeat the same wiring and return lines
  evidence: |
      if (current === null) {
        const primaryChildFragment = mountWorkInProgressOffscreenFiber(
          offscreenChildProps, mode, renderLanes,
        );
        primaryChildFragment.ref = workInProgress.ref;
        workInProgress.child = primaryChildFragment;
        primaryChildFragment.return = workInProgress;

        return primaryChildFragment;
      } else {
        const currentChild: Fiber = (current.child: any);
        const primaryChildFragment = updateWorkInProgressOffscreenFiber(
          currentChild, offscreenChildProps,
        );
        primaryChildFragment.ref = workInProgress.ref;
        workInProgress.child = primaryChildFragment;
        primaryChildFragment.return = workInProgress;
        return primaryChildFragment;
      }
  evidence_refs:
    - packages/react-reconciler/src/ReactFiberBeginWork.js:2352-2354
  impact: The `if` and `else` branches differ only in which fiber helper they call. The four lines after it (`ref`, `child`, `return`, then the return statement) are copied word for word. The same wiring appears in `mountSuspensePrimaryChildren` at ReactFiberBeginWork.js:2352-2354. A later change to how the child fiber is attached (for example, also resetting `sibling` as `updateSuspensePrimaryChildren` does at line 2462) would need to be made in two places.
  remedy: Use the branch only to choose the fiber, e.g. `const primaryChildFragment = current === null ? mountWorkInProgressOffscreenFiber(offscreenChildProps, mode, renderLanes) : updateWorkInProgressOffscreenFiber((current.child: any), offscreenChildProps);`. Then set `ref`, `child` and `return` once and return.
  confidence: high
  overlap_hints: [craft.code-judo]

## Files examined
examined: [packages/react-devtools-shared/src/backend/fiber/renderer.js, packages/react-devtools-shared/src/backend/types.js, packages/react-reconciler/src/ReactFiber.js, packages/react-reconciler/src/ReactFiberBeginWork.js, packages/react-reconciler/src/ReactFiberCompleteWork.js, packages/react-reconciler/src/ReactWorkTags.js, packages/react-reconciler/src/getComponentNameFromFiber.js, packages/react-server/src/ReactFizzServer.js, packages/react/src/ReactClient.js, packages/shared/ReactSymbols.js, packages/shared/isValidElementType.js]
not_examined: []
