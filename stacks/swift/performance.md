# Stack pack: swift — performance
extends: core/skills/performance/SKILL.md

## Stack-specific signals
- iOS: heavy work / decoding / layout on the main thread → frame drops / launch jank; `UIImage(data:)` / large images on main without downsampling.
- SwiftUI: recomputing expensive derived state in `body` instead of `@StateObject`/`@State` memoization; `List` of non-`Identifiable` rows causing full rebuilds.
- Unbounded `Task`/`async let` fan-out instead of a bounded `TaskGroup`; missing prefetch/pagination on large lists.
- Repeated JSON decoding / image loading per cell in `UICollectionView`/`List` instead of caching (`NSCache`, async prefetch).
- N+1 fetches in a loop (see db pack).

## Stack-specific remedies
- Move decode/compute off main; downsample images; memoize derived state; cache/prefetch; bound `TaskGroup`; paginate.

## Stack-specific severity guidance
- Main-thread decode/large image on a real screen: High.
- Unbounded `Task` fan-out: High (availability).
- Premature micro-tuning without measured jank: do not report.
