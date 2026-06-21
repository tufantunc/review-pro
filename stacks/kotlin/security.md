# Stack pack: kotlin — security
extends: core/skills/security/SKILL.md

## Stack-specific signals
- SQL via string interpolation (`"SELECT ... WHERE id = $id"`, `+`) in Exposed/JDBC/Room raw queries → SQL injection; use parameterized queries / typed DSL.
- Android: cleartext HTTP (`usesCleartextTraffic="true"`), exported components (`android:exported="true"`) without permission checks, implicit intents carrying secrets.
- Hardcoded API keys/seeds in `BuildConfig`, `strings.xml`, or `SharedPreferences` (world-readable) — extract from the APK.
- `WebView` with `setJavaScriptEnabled(true)` + `addJavascriptInterface` exposing app objects, or loading user-controlled URLs.
- Ktor/Spring endpoint missing authz; CORS `*` with credentials; CSRF disabled on state-changing routes.
- Java `ObjectInputStream` / `XmlDecoder` / Kryo on untrusted data → deserialization RCE.
- `SecureRandom` swapped for `Random` for tokens; MD5/SHA1 for passwords (use PBKDF2/argon2).

## Stack-specific remedies
- Parameterize SQL (`PreparedStatement`, Exposed typed DSL, Room `@Query` with `:param`); no cleartext; scope exported components; no secrets in client bundles; `argon2`/PBKDF2.

## Stack-specific severity guidance
- String-interpolated SQL / exported component without authz: Critical/High.
- Secret baked into the APK / `addJavascriptInterface`: High.
