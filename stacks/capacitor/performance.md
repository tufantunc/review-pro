# Stack pack: capacitor — performance
extends: core/skills/performance/SKILL.md

## Stack-specific signals
- Native bridge churned every render/animation frame — unbatched `Plugin` calls or `addListener` events inside a scroll/render loop.
- Heavy synchronous JS on the WebView UI thread during scroll/animation (parse, big reduce, image decode) → frame drops; should be chunked or offloaded.
- Large base64 payloads sent across the bridge (images, files) instead of passing a File/URI the native side reads directly.
- Plugin listener (`networkStatusChange`, `resize`, `appStateChange`) added without throttle/debounce and never `.remove()`d → event storm + growing callback list per navigation.
- `Camera.getPhoto()` without `quality`/`resultType`/`width`/`height` → multi-MB image base64-decoded in the WebView → memory spike / OOM.
- `Device.getInfo()` / `Geolocation.getCurrentPosition()` called on every render instead of once and cached.
- Splash misconfigured: `launchAutoHide: true` with no `launchShowDuration`, or content hidden before web bundle paints → white flash / frozen splash.
- LiveReload web-socket / dev server connection left enabled in a production build.
- Push token registered on every app launch without caching the last token → redundant FCM/APNs calls.

## Stack-specific remedies
- Batch/debounce bridge calls; pass files by URI; cap and resize image output; cache device/geolocation reads; remove listeners on unmount; gate LiveReload to dev; cache the push token and re-register only on change.

## Stack-specific severity guidance
- Per-frame bridge calls / unbounded camera image in WebView / dev connection in prod: High.
- Missing throttle on bridge events / uncached `Device.getInfo` per render: Medium.
- Splash micro-tuning without a measured blank-screen: do not report.
