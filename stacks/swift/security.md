# Stack pack: swift — security
extends: core/skills/security/SKILL.md

## Stack-specific signals
- iOS: ATS disabled (`NSAllowsArbitraryLoads`), cleartext HTTP, or `WKWebView` loading user-controlled URLs with JS enabled + message handlers exposing app state.
- Keychain items stored with `kSecAttrAccessibleAlways` / default accessibility instead of `WhenUnlockedThisDeviceOnly`; secrets in `UserDefaults` / plist.
- Hardcoded API keys / certs in the app bundle (extractable from the IPA).
- `NSSecureCoding`/`NSKeyedUnarchiver` on untrusted data, or `@objc` exposed to JS/bridges → unsafe deserialization.
- Vapor endpoint missing authz / CSRF protection on state-changing routes; permissive CORS with credentials.
- `RandomNumberGenerator` default / `arc4random` misused for tokens (prefer `SystemRandomNumberGenerator`); weak hashing (`MD5`/`SHA1`) for passwords (use CryptoKit `PBE`/argon2).
- SQL string interpolation in GRDB/Vapor Fluent raw queries → SQL injection.

## Stack-specific remedies
- Keep ATS on; confine webview URLs; `WhenUnlockedThisDeviceOnly` for keychain; no secrets in bundle; parameterize SQL; CryptoKit/SystemRandomNumberGenerator.

## Stack-specific severity guidance
- ATS off / `WKWebView` on user URLs / Keychain `Always`: High.
- String-interpolated SQL / secret in bundle: Critical/High.
