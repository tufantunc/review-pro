# Stack pack: typescript-react — security
extends: core/skills/security/SKILL.md

## Stack-specific signals
- `dangerouslySetInnerHTML` fed with user-controlled input → XSS (High by default).
- Secrets shipped to the client via `NEXT_PUBLIC_*` / `VITE_*` / `process.env.NEXT_PUBLIC_*` exposed in components.
- Auth tokens stored in `localStorage` / `sessionStorage` (XSS-exfiltratable).
- `target="_blank"` links without `rel="noopener noreferrer"` (reverse tabnabbing).
- `eval(...)` / `new Function(...)` / `setTimeout(string)` on dynamic data.
- Unescaped interpolation into `href`/`src` allowing `javascript:` URLs.

## Stack-specific remedies
- Sanitize HTML with DOMPurify before `dangerouslySetInnerHTML`; prefer text interpolation.
- Keep secrets server-side; pass only non-sensitive config to the client.
- Prefer httpOnly cookies for session tokens.
- Use `rel="noopener noreferrer"` (modern browsers default this, but be explicit in libraries).

## Stack-specific severity guidance
- XSS via `dangerouslySetInnerHTML` + user input: Critical (direct script execution in user session).
- Client-exposed secret via `NEXT_PUBLIC_*`: High (leak is permanent in the bundle).
