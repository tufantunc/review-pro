# Stack pack: dotnet — security
extends: core/skills/security/SKILL.md

## Stack-specific signals
- `FromSqlRaw` / `FromSqlInterpolated` with string concatenation, or ADO.NET `SqlCommand` string-built SQL → SQL injection.
- Path handling on user input without `Path.GetFullPath` + confinement → path traversal.
- `BinaryFormatter` / `XmlSerializer` on untrusted data / `JsonTypeNameHandling.Auto` → deserialization RCE.
- `MD5` / `SHA1` for passwords/hashes; `Random` for tokens (use `RandomNumberGenerator`).
- ASP.NET Core endpoint missing `[Authorize]` / `[AllowAnonymous]` widening access; permissive CORS (`AllowAnyOrigin` + `AllowCredentials`).
- Missing antiforgery on state-changing form posts; secrets in `appsettings.json` committed to the repo.
- `Razor` `@Html.Raw(userContent)` → XSS.

## Stack-specific remedies
- Parameterize (`FromSqlInterpolated` with parameters / `SqlParameter`); confine paths; use `Html.Raw` never on user content.
- Use `BCrypt`/`PBKDF2`/`argon2`; `[Authorize]` per endpoint; scoped CORS; antiforgery; secrets via Secret Manager/user-secrets or env.

## Stack-specific severity guidance
- String-built SQL / `BinaryFormatter` on untrusted input / `@Html.Raw(user)`: Critical/High.
- Missing `[Authorize]` on a mutating endpoint: High.
- `MD5`/`Random` for security: High.
