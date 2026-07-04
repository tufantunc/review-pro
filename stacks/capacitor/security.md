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
- Secret in bundle / custom-scheme OAuth without PKCE / remote `server.url` with full bridge: Critical.
- Sensitive token in `Preferences` / no CSP / cleartext traffic: High.
- Over-broad permission declaration or missing privacy manifest: Medium/High.
