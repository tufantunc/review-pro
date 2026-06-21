# Stack pack: react-native — performance
extends: core/skills/performance/SKILL.md

## Stack-specific signals
- Rendering long lists with `ScrollView` instead of `FlatList`/`FlashList`/`SectionList` → all items mounted → memory + scroll jank.
- Inline functions / new object props on list item render breaking `React.memo`/`getItemLayout`; missing `keyExtractor`.
- Heavy JS work on the JS thread during render/animation (parse, sync network, big reduce) → frame drops; should be offloaded or batched.
- Unoptimized images: large local/remote images without resize/caching (`react-native-fast-image`, proper `resizeMode`); re-decoding per render.
- Bridge/JS<->native churn: large payloads sent across the bridge per frame; unbatched native module calls in a loop.
- Re-renders cascading because parent state changes when only a child needs it.

## Stack-specific remedies
- Virtualize long lists; stabilize item props; memoize; offload heavy JS; cache/resize images; keep state at the smallest owner.

## Stack-specific severity guidance
- `ScrollView` for a large list / heavy JS on the JS thread on a real screen: High.
- Inline prop allocation breaking memoization: Medium/High.
