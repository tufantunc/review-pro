# Stack pack: capacitor — frontend
extends: core/skills/frontend/SKILL.md

## Stack-specific signals
- No safe-area-inset handling (`safe-area-inset-*` CSS env / a safe-area plugin) → content sits under the notch, status bar, or home indicator.
- Platform UX ignored: iOS vs Android tap-target and back behavior, Android hardware back (`App.addListener('backButton')`) unhandled → app exits instead of navigating back; iOS swipe-back not respected.
- Browser-only navigation assumptions in the native WebView origin (`capacitor://` / `http://localhost`): absolute fetch URLs, `window.open`/`target="_blank"` used without the InAppBrowser/Browser plugin.
- Hover/`cursor`/desktop-drag interactions with no touch equivalent; hover-only affordances unreachable on touch.
- Keyboard not configured (resize mode, accessory bar) → inputs scroll-jacked or hidden by the keyboard; `Keyboard` plugin events ignored.
- Status bar / navigation bar overlap and style (light/dark) not handled; content shift on orientation change not accounted for.
- Synchronous `getPlatform()` branch in render causing a visible flicker between web/native UI; native-only feature with no web fallback UI.
- Splash/status-bar content shown above a transparent web view without matching background → color pop on launch.

## Stack-specific remedies
- Apply safe-area insets; handle Android back + iOS swipe; route external links through the Browser/InAppBrowser plugin; add touch equivalents for hover; configure the Keyboard plugin; match status-bar style to content and provide a web fallback.

## Stack-specific severity guidance
- Unhandled Android back / content under notch or keyboard / no web fallback for a native feature: Medium/High.
- Status-bar style flicker or orientation shift: Medium.
