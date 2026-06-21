# Stack pack: flutter — performance
extends: core/skills/performance/SKILL.md

## Stack-specific signals
- Rebuilding the whole tree on each frame/state change (missing `const`, missing `RepaintBoundary`, building inside `build`).
- `ListView` (builds all children) instead of `ListView.builder` for large/unknown lists → jank + memory.
- Heavy synchronous work inside `build` / animations (parse, network, file) → frame drops.
- Oversized images loaded without `cacheWidth`/`cacheHeight` → large decode memory; missing `Image.memory` downsampling.
- Unbounded `setState` triggering cascades; `MediaQuery`/`InheritedWidget` reads causing whole-tree rebuilds.
- Allocation churn from building large widget lists inline each rebuild.

## Stack-specific remedies
- `const` widgets + `RepaintBoundary` boundaries; `ListView.builder` for long lists.
- Move heavy work off `build` (compute/Isolate); specify `cacheWidth`/`cacheHeight`; scope `setState` to the minimal subtree.

## Stack-specific severity guidance
- Non-builder `ListView` / heavy work in `build` on a real screen: High.
- Missing `const` causing measurable rebuild cost: Medium/High.
- Micro-tuning without measured jank: do not report.
