# Stack pack: capacitor — correctness
extends: core/skills/correctness/SKILL.md

## Stack-specific signals
- Plugin used after install/upgrade without running `npx cap sync` → native project missing the plugin, runtime "not implemented" / unresolved import.
- Major-version mismatch: `@capacitor/core` major (6/7/8) differs from an installed `@capacitor/*` plugin's major → incompatible bridge, native crash or silent no-op.
- Plugin with no `web` implementation called in the PWA/browser build and not feature-gated via `Capacitor.getPlatform()`/`implements` → broken web target.
- `capacitor.config.ts` `server.url` / `server.androidScheme` left pointing at a dev/LiveReload URL and shipped to production → blank screen / app loads the dev server in prod.
- `App.addListener('appUrlOpen', …)` deep-link listener registered but its handle never `.remove()`d on unmount, or never registered at all → stale navigation / deep links silently ignored.
- Long-running native resource (geolocation `watchPosition`, media, background task) not stopped on `appStateChange` background or on unmount → leaked native handle / battery drain / crash.
- Permission requested at module load or during render instead of on a user gesture (iOS requires it for some; push notifications on both) → prompt suppressed or denied.
- Plugin result relied on before checking permission state (`denied`) → silent failure with no user feedback.
- File path passed where a Capacitor URI (`capacitor://`, `http://localhost`) is required (or vice versa) → Filesystem/Camera/Preview can't resolve.
- `Capacitor.getPlatform()` / `isNativeAvailable()` branched synchronously during SSR/prerender of the web build → wrong initial render / hydration mismatch.

## Stack-specific remedies
- Run `capacitor sync` after every plugin change; align plugin majors to core; provide/feature-gate a web fallback; keep `server.url` env-gated out of prod; remove listeners and stop watches on unmount/background; request permissions from a user gesture and handle `denied`.

## Stack-specific severity guidance
- Plugin major mismatch / prod build pointing at dev `server.url` / missing `cap sync`: High.
- Listener/watch leak or unhandled `denied` permission state: Medium/High.
- Web fallback missing for a plugin used in a PWA target: Medium.
