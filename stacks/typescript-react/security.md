# Stack pack: typescript-react — security
extends: core/skills/security/SKILL.md

## Stack-specific signals
- `dangerouslySetInnerHTML` fed with user-controlled input → XSS (High by default).
- Secrets shipped to the client via `NEXT_PUBLIC_*` / `VITE_*` / `process.env.NEXT_PUBLIC_*` exposed in components.
- Auth tokens stored in `localStorage` / `sessionStorage` (XSS-exfiltratable).
- `target="_blank"` links without `rel="noopener noreferrer"` (reverse tabnabbing).
- `eval(...)` / `new Function(...)` / `setTimeout(string)` on dynamic data.
- Unescaped interpolation into `href`/`src` allowing `javascript:` URLs.
- Input from the URL (query, path, or hash), `window.name`, `postMessage`, or storage another origin can write, reaching `dangerouslySetInnerHTML` or `innerHTML` → reflected or DOM XSS, not self-XSS.
- `DOMPurify` run on the server with happy-dom or an outdated jsdom, or its output changed after `sanitize` → the sanitizer's maintainers do not support that DOM, and a modified output is no longer the sanitized one.

## Stack-specific remedies
- Sanitize HTML with DOMPurify before `dangerouslySetInnerHTML`; prefer text interpolation.
- Keep secrets server-side; pass only non-sensitive config to the client.
- Prefer httpOnly cookies for session tokens.
- Use `rel="noopener noreferrer"` (modern browsers default this, but be explicit in libraries).

## Stack-specific severity guidance
- XSS via `dangerouslySetInnerHTML` + input another user controls: High (script runs in that user's session); Critical when it runs in an administrator's session or yields account takeover.
- Client-exposed secret via `NEXT_PUBLIC_*`: High (leak is permanent in the bundle).
