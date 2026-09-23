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
- XSS via `dangerouslySetInnerHTML` + input another user controls: High (script runs in that user's session); Critical when it runs in an administrator's session or yields account takeover.
- Client-exposed secret via `NEXT_PUBLIC_*`: High (leak is permanent in the bundle).

## Not a finding
- `{value}` text interpolation in JSX: React escapes it. That covers text only; React does not escape, for example, `dangerouslySetInnerHTML`, `srcDoc`, a `javascript:` URL in a URL prop, props spread from input, or a DOM API such as `innerHTML` reached through a ref.
- A value a user renders only into their own session. Self-XSS is not a finding unless another user's input can reach the same sink. Input from any source the current user did not type in this session is input someone else controls, for example the URL (query, path, or hash), `document.referrer`, `window.name`, `postMessage`, a shared link, or storage and cookies another origin or subdomain can write. That is reflected or DOM XSS, not self-XSS.
- `target="_blank"` without `rel="noopener"`: current browsers apply `noopener` to `_blank` links by default. It is a finding only when the link sets `rel="opener"` or the project must support browsers from before 2021.
