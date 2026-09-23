# Stack pack: dotnet — security
extends: core/skills/security/SKILL.md

## Stack-specific signals
- `FromSqlRaw` / `FromSqlInterpolated` with string concatenation, or ADO.NET `SqlCommand` string-built SQL → SQL injection.
- Path handling on user input without `Path.GetFullPath` + confinement → path traversal.
- `BinaryFormatter` on untrusted data, `XmlSerializer` whose type comes from the payload or from input, or Newtonsoft.Json with `TypeNameHandling` other than `None` → deserialization RCE.
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

## Not a finding
- `FromSqlInterpolated($"... {id}")` and EF Core 7+ `FromSql($"... {id}")`: the interpolated literal becomes a `FormattableString` and every hole becomes a parameter. The unsafe forms are `FromSqlRaw` fed a string that was already concatenated or interpolated, and `SqlCommand` text built the same way.
- `XmlSerializer` built with a fixed `typeof(T)`, and `System.Text.Json` without polymorphic type handling. Neither lets the payload choose the type, which is what makes deserialization dangerous.
- Razor `@value`: output is HTML-encoded by default. Only `@Html.Raw`, `HtmlString`, and `MarkupString` bypass the encoder.
- `[AllowAnonymous]` on endpoints meant to be public: sign-in, health checks, public content. It is a finding when it lands on a mutating or private endpoint, or overrides a controller-level `[Authorize]` for an action that should inherit it.
- `System.Random` for non-security work: jitter, sampling, shuffling display order.
