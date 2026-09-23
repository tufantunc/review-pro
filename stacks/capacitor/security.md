# Stack pack: capacitor — security
extends: core/skills/security/SKILL.md

## Stack-specific signals
- Secret/API key embedded in the web bundle or injected at build time via an env-var plugin — the JS bundle ships inside the app and is trivially extracted via basic app analysis.
- Session token / encryption key stored in `@capacitor/preferences` (backed by plain UserDefaults / SharedPreferences) instead of Keychain/Keystore.
- OAuth or sensitive data routed through a **custom URL scheme** (`myapp://`) — a malicious app can register the same scheme and intercept the token; OAuth must use Universal Links/App Links (domain-bound) + PKCE.
- `capacitor.config.ts` `server.url` set to a remote host (LiveReload or otherwise) that loads an external page with the **full native bridge exposed** → arbitrary remote page can call any plugin.
- Plain `http://` requests; `android:usesCleartextTraffic="true"` or iOS ATS disabled; no cert pinning on authenticated calls.
- WebView with no CSP or a permissive one (`default-src *`, `unsafe-inline` + `unsafe-eval`); `allowFileAccess`/`allowUniversalAccessFromFileURLs` enabled for remote content.
- Native permissions over-declared (location-always, read-external-storage-all, camera) in `Info.plist` / `AndroidManifest.xml` that the feature doesn't use.
- iOS `PrivacyInfo.xcprivacy` (Privacy Manifest) missing required `NSPrivacyAccessedAPITypes`; Android `POST_NOTIFICATIONS` (API 33+) runtime grant missing for push.

## Stack-specific remedies
- Keep secrets server-side; store tokens in Keychain/Keystore via a secure-storage plugin; deep-link auth via Universal/App Links + PKCE; scope CSP, permissions, and the native bridge to the app origin; disable cleartext and pin certs.

## Stack-specific severity guidance
- A privileged secret in the bundle (one that grants what the server should gate) / custom-scheme OAuth without PKCE / remote `server.url` with full bridge: Critical.
- Sensitive token in `Preferences` / cleartext traffic carrying credentials: High. No CSP on its own: Low, a second layer; High only alongside an injection path it would have stopped.
- Over-broad permission declaration: Low, least privilege with no boundary crossed on its own. Missing privacy manifest: Low here; it blocks App Store submission, which is a release problem rather than a vulnerability.

## Not a finding
- `server.url` pointing at `localhost` or a LAN address when it is set only under a development flag that release builds do not carry. Confirm the flag is absent from the release configuration before dismissing it.
- `usesCleartextTraffic` or an ATS exception limited to `localhost` or `10.0.2.2` in a debug-only build configuration.
- Non-secret preferences (theme, locale, onboarding state) in `@capacitor/preferences`. Only credentials and keys need Keychain or Keystore.
