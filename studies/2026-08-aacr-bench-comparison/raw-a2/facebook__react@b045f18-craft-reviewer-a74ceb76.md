<!-- facebook__react@b045f18 craft-reviewer; verbatim final answer -->
- severity: High
  category: craft.layer-leak
  file: packages/react-devtools-shared/src/backend/fiber/renderer.js
  line: 149
  title: DevTools reads the Activity tag from the reconciler's source constant, not from its own version map, which leaves the new map entries unused
  evidence: |
    import {ActivityComponent} from 'react-reconciler/src/ReactWorkTags';
    ...
          ViewTransitionComponent: 30, // Experimental
          ActivityComponent: 31,
    ...
          ActivityComponent: -1, // Doesn't exist yet   (x4 older-version branches)
    ...
      const {
        ...
        Throw,
        ViewTransitionComponent,
      } = ReactTypeOfWork;          // ActivityComponent not destructured (line ~556 and ~902)
    ...
          case ActivityComponent:
            return 'Activity';      // line 631, uses the module import
    ...
          case ActivityComponent:   // line 1491, in attach(), also the module import
  evidence_refs: [packages/react-devtools-shared/src/backend/fiber/renderer.js:389, packages/react-devtools-shared/src/backend/fiber/renderer.js:556, packages/react-devtools-shared/src/backend/fiber/renderer.js:902, packages/react-devtools-shared/src/backend/fiber/renderer.js:631, packages/react-devtools-shared/src/backend/fiber/renderer.js:1491]
  impact: The DevTools backend has to work with many React versions. That is why every work tag goes through the version-keyed `ReactTypeOfWork` map, gets destructured in `getInternalReactConstants` and `attach()`, and why the backend imports only *types* from `react-reconciler`. This change adds the first runtime value import from reconciler source. It also adds five `ActivityComponent` entries to the map, the `WorkTagMap` type and the older-version `-1` fallbacks, and none of them are ever read. So 31 is treated as Activity for every connected renderer, whatever the version. The map now looks complete while being bypassed for this one tag, and the next person to copy the pattern will repeat the problem.
  remedy: Delete the `react-reconciler/src/ReactWorkTags` import. Add `ActivityComponent` to both `const {...} = ReactTypeOfWork` destructures (in `getInternalReactConstants` near line 556 and in `attach()` near line 902), next to `ViewTransitionComponent`, so both `case ActivityComponent:` sites use the version-resolved value like every other tag.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Medium
  category: craft.code-judo
  file: packages/react-reconciler/src/ReactFiberBeginWork.js
  line: 885
  title: updateActivityComponent's mount and update branches repeat the same wiring code
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
        const currentChild: Fiber = (current.child: any);

        const primaryChildFragment = updateWorkInProgressOffscreenFiber(
          currentChild,
          offscreenChildProps,
        );

        primaryChildFragment.ref = workInProgress.ref;
        workInProgress.child = primaryChildFragment;
        primaryChildFragment.return = workInProgress;
        return primaryChildFragment;
      }
  impact: The only real difference between the branches is how the child fiber is created. The ref/child/return wiring and the return statement are written out twice. A later change to that wiring, for example adding `sibling = null` or flags as `updateSuspensePrimaryChildren` does, has to be made in both places, and the two copies can drift apart without anyone noticing.
  remedy: Keep the branch only for choosing how to create the child, then wire it once. For example `const primaryChildFragment = current === null ? mountWorkInProgressOffscreenFiber(offscreenChildProps, mode, renderLanes) : updateWorkInProgressOffscreenFiber((current.child: any), offscreenChildProps);`, followed by a single block of `ref`/`child`/`return` assignments and one `return`. This removes about 10 lines and the duplicated wiring, and behavior stays the same.
  confidence: high
  overlap_hints: [dry.duplication]

- severity: Low
  category: craft.abstraction
  file: packages/react-reconciler/src/ReactFiber.js
  line: 881
  title: Activity's public props are typed with Offscreen's internal props type
  evidence: |
    }
    export function createFiberFromActivity(
      pendingProps: OffscreenProps,
      mode: TypeOfMode,
      lanes: Lanes,
      key: null | string,
    ): Fiber {
      const fiber = createFiber(ActivityComponent, pendingProps, key, mode);
  evidence_refs: [packages/react-reconciler/src/ReactFiberActivityComponent.js:20]
  impact: The point of this refactor is to separate the public `<Activity>` element from the internal Offscreen fiber. The new constructor still declares its props as `OffscreenProps`, and that type's own comment says it is an unchosen API ("TODO: Pick an API before exposing the Offscreen type"). So the user-facing Activity props are tied to an internal type. Changing Offscreen's props would change Activity's contract without anyone noticing, and the code doesn't say which props Activity accepts. This function is also missing the blank line that separates every other `createFiberFrom*` function.
  remedy: Define an `ActivityProps` type (`mode?: 'hidden' | 'visible' | null | void, children?: ReactNodeList`) in `ReactFiberActivityComponent.js` and use it in `createFiberFromActivity`. In `updateActivityComponent`, read `nextProps` through that type and map it into `OffscreenProps` explicitly, so the Activity-to-Offscreen translation happens in one place. Add the missing blank line before the function.
  confidence: medium
  overlap_hints: [api-contract.type-boundary]

## Files examined
examined: [packages/react-devtools-shared/src/backend/fiber/renderer.js, packages/react-devtools-shared/src/backend/types.js, packages/react-reconciler/src/ReactFiber.js, packages/react-reconciler/src/ReactFiberBeginWork.js, packages/react-reconciler/src/ReactFiberCompleteWork.js, packages/react-reconciler/src/ReactWorkTags.js, packages/react-reconciler/src/getComponentNameFromFiber.js, packages/react-server/src/ReactFizzServer.js, packages/react/src/ReactClient.js, packages/shared/ReactSymbols.js, packages/shared/isValidElementType.js]
not_examined: []
