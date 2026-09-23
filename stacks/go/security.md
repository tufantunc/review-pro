# Stack pack: go — security
extends: core/skills/security/SKILL.md

## Stack-specific signals
- `database/sql` query built with `fmt.Sprintf`/`+` instead of placeholders (`db.Query("... WHERE id = $1", id)`) → SQL injection.
- `text/template` used to render HTML (no escaping) instead of `html/template` → XSS.
- `os/exec.Command("sh", "-c", userInput)` / `exec.Command(userInput)` → command injection.
- `filepath.Join(userInput)` / `os.Open(userInput)` without confining to a base dir (`filepath.Rel` + prefix check) → path traversal.
- `math/rand` used for tokens/secrets/sessions instead of `crypto/rand`.
- `crypto/md5` / `crypto/sha1` / `crypto/des` for passwords/security → weak crypto; use `golang.org/x/crypto/bcrypt` / `argon2`.
- `TLSConfig{InsecureSkipVerify: true}` disabling cert validation.

## Stack-specific remedies
- Parameterize SQL (`$1`, `?`); use `html/template` for HTML; arg-array `exec.Command`.
- Bound paths to a known root; use `crypto/rand` + `bcrypt`/`argon2`; never `InsecureSkipVerify`.

## Stack-specific severity guidance
- String-built SQL / `sh -c` with input / `InsecureSkipVerify`: Critical/High.
- `math/rand` for a security token: High.

## Not a finding
- `html/template` rendering user data: it escapes by context. The escape hatches are values converted to `template.HTML`, `template.JS`, `template.URL`, or `template.HTMLAttr`; flag those when the value is user-controlled.
- `exec.Command("git", "log", userArg)`: arguments go to the program directly, with no shell to inject into. Option injection remains when the value can start with `-`; report that as injection, naming the flag an attacker could pass.
- `InsecureSkipVerify: true` in a `_test.go` file against an `httptest.NewTLSServer`.
- `math/rand` for jitter, sampling, load balancing, or shuffling. It is a finding only for tokens, keys, nonces, or anything an attacker must not predict.
- `filepath.Join` where every segment is a constant or comes from the program's own configuration, not from a request.
