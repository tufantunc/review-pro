# Stack pack: swift — security
extends: core/skills/security/SKILL.md

## Stack-specific signals
- iOS: ATS disabled (`NSAllowsArbitraryLoads`), cleartext HTTP, or `WKWebView` loading user-controlled URLs with JS enabled + message handlers exposing app state.
- Keychain items stored with `kSecAttrAccessibleAlways` / default accessibility instead of `WhenUnlockedThisDeviceOnly`; secrets in `UserDefaults` / plist.
- Hardcoded API keys / certs in the app bundle (extractable from the IPA).
- `NSSecureCoding`/`NSKeyedUnarchiver` on untrusted data, or `@objc` exposed to JS/bridges → unsafe deserialization.
- Vapor endpoint missing authz / CSRF protection on state-changing routes; permissive CORS with credentials.
- A custom or seeded `RandomNumberGenerator` (a reproducible-test generator, say) used for tokens; weak hashing (`MD5`/`SHA1`) for passwords (use Vapor's `Bcrypt` on the server, PBKDF2 via CommonCrypto `CCKeyDerivationPBKDF` on device, or argon2).
- SQL string interpolation in GRDB/Vapor Fluent raw queries → SQL injection.

## Stack-specific remedies
- Keep ATS on; confine webview URLs; `WhenUnlockedThisDeviceOnly` for keychain; no secrets in bundle; parameterize SQL; CryptoKit/SystemRandomNumberGenerator.

## Stack-specific severity guidance
- ATS off / `WKWebView` on user URLs / Keychain `Always`: High.
- String-interpolated SQL / secret in bundle: Critical/High.

## Not a finding
- `Int.random(in:)`, `SystemRandomNumberGenerator`, `SecRandomCopyBytes`, and `arc4random` for tokens. All draw from a cryptographically secure generator on Apple platforms, and `SystemRandomNumberGenerator` is the default behind `random(in:)`.
- A Keychain item with the default accessibility (`kSecAttrAccessibleWhenUnlocked`). `ThisDeviceOnly` matters only when the item must not move to a new device through a backup, and `AfterFirstUnlock` is correct for items a background task has to read.
- `NSKeyedUnarchiver.unarchivedObject(ofClass:from:)` or `ofClasses:` with a fixed set of classes: secure coding restricts what the archive can instantiate. The finding is the deprecated `unarchiveObject(with:)` on untrusted data.
- `WKWebView` loading only bundled files or a fixed first-party origin.
