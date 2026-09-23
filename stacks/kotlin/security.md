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

## Not a finding
- Room `@Query("... WHERE id = :id")`, `rawQuery(sql, selectionArgs)` with `?` placeholders, JDBC `PreparedStatement` parameters, and the Exposed DSL: these bind values instead of splicing them into SQL.
- `android:exported="true"` on the launcher activity (the one with the `MAIN`/`LAUNCHER` intent filter), which must be exported to start at all. The finding is an exported component that performs a privileged action or returns private data without a permission check.
- `usesCleartextTraffic`, or a network security config allowing cleartext, scoped to a debug build type or to `localhost`/`10.0.2.2`.
- `kotlin.random.Random` for non-security work: animation, sampling, shuffling display order.
