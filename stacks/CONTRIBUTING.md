# Contributing a stack pack

A **stack pack** adds language/framework-specific signals to a reviewer's core rubric. Packs live in `stacks/<pack>/` and ship in the catalog; users install them into a repo's `.review-pro/` via `npx review-pro`. This guide is how to add one.

## Before you write

- A pack only earns its place if it adds **concrete, stack-specific** signals the core rubric doesn't already cover. "Be careful with errors" is core territory; "`eval()` on dynamic input → RCE in CPython" is a python-pack signal.
- **Focused, not exhaustive.** Write a pack file only for reviewers where the stack genuinely adds value (see `typescript-react` with 8, `node` with 7). Skip reviewers where you'd be inventing thin signals.
- Verify signals against the real stack — no myths. If unsure, leave it out.

## Pack layout

```
stacks/<pack>/
  manifest.json          # name, version, description, reviewers
  <reviewer>.md          # one file per reviewer you cover
```

## `manifest.json`

```json
{
  "name": "python",
  "version": "0.1.0",
  "description": "Python signals for review-pro reviewers",
  "reviewers": ["security", "correctness", "craft", "backend", "db", "api-contract", "performance", "tests"]
}
```

Rules (enforced by `scripts/validate.sh`):
- `version` is semver (`x.y.z`).
- Every entry in `reviewers` must (a) match a core skill in `core/skills/` and (b) have a matching `<reviewer>.md` file in the pack dir.

## Pack file format

```markdown
# Stack pack: <pack> — <reviewer>
extends: core/skills/<reviewer>/SKILL.md

## Stack-specific signals
- concrete thing to flag, with the stack-specific mechanism

## Stack-specific remedies
- concrete fix using this stack's idioms/tools

## Stack-specific severity guidance
- how this stack adjusts severity (e.g. "XSS via mark_safe: Critical")
```

Keep each signal one line, concrete, and tied to a real API/construct in the stack.

A `security.md` also ends with a fourth section, `## Not a finding`: the safe forms of the file's own signals, each naming the condition that makes it safe (`subprocess.run([...])` without `shell=True`, `yaml.safe_load`). A pattern-shaped signal fires on everything that resembles it, and this section is what stops it firing on the code that only looks the same. `scripts/validate.sh` fails a security pack without the section.

List only what depends on the stack. Rules that hold everywhere (self-impact, publishable keys, non-security randomness, option injection through an argument array, an escaper that does not fit its sink) live once in `core/skills/security/SKILL.md`, which reaches the reviewer with every pack. A copy in a pack drifts from the original, and packs compose, so a Next.js repo would receive each copy twice. An entry is one of two kinds, and either way the narrowest case you are sure of. A shape entry is safe by the form of the call, whatever the data: `yaml.safe_load`, literal SQL with bound parameters, an argument array with no shell once it names the option-injection risk that remains. A context entry is cleared by a condition the reviewer confirms in the repository, such as a release configuration, a data source that serves only public data, or a constant, and never by the content of the data. The rubric states both, so a reviewer knows which kind of check an entry asks for. Never list output escaping or a sanitizer. The first version of these sections did, and four review passes each found another context the escaping entries cleared by mistake: an unquoted attribute, an event handler, a client-side template root, a JSON value placed inside quotes, a sanitizer on a DOM its own maintainers call unsafe. A fifth pass found the same failure in the rubric's own guidance wherever it said an escaper was safe somewhere, so the rubric now lists only known mismatches and makes no claim that any placement is safe. A clearance that is wrong fails toward shipping a vulnerability, and a context-dependent one is wrong somewhere, so those cases are left to the rubric's rule on fitting the escaper to the sink, which tells the reviewer how to judge them rather than excusing them.

Three other shapes clear real vulnerabilities: a list that reads as complete ("Only X, Y, and Z bypass the encoder") clears whatever it forgets; a condition the attacker controls (a property of their own upload) is not a safety condition; and a version floor decays when a later advisory moves it, so cite the advisories it rests on.

When a safe form keeps a risk the rubric already names, point to the rule instead of restating it, the way five packs end their argument-array entry with "Option injection still applies, per the rubric's injection rule."

Severity lines refine the anchors in `core/skills/security/SKILL.md`; they do not replace them. When a pack line and an anchor disagree about the same path, the anchor wins, so a pack line that contradicts one is a bug in the pack.

## Authoring checklist

- [ ] `manifest.json` has `name`, `version`, `reviewers`.
- [ ] Every listed reviewer has a `<reviewer>.md` file.
- [ ] Each file has the three sections (signals / remedies / severity), and a `security.md` also has `## Not a finding`.
- [ ] Signals are stack-specific (not core-rubric rehash).
- [ ] `./scripts/validate.sh` passes.
- [ ] (Optional) smoke the composition: from a repo with `.review-pro/<pack>/`, run the review and confirm the new signals surface in findings.

## How packs reach users

1. `npm run build` (in `cli/`) bundles `stacks/` → `cli/catalog/`.
2. `npx review-pro` (interactive) or `add <pack>` copies `stacks/<pack>/` into the user's repo `.review-pro/<pack>/`.
3. At review time the orchestrator reads `.review-pro/<pack>/<reviewer>.md` and passes them to reviewers as `### Stack signals`.
4. `npx review-pro update` re-copies a pack only when its `manifest.json` `version` differs from the installed copy. **Any change to a pack file must bump that pack's `version`**, or existing installs keep the old content and `update` reports them as already latest. Nothing checks this yet.
