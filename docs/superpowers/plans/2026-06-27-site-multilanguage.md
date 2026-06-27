# Site Multi-Language Support — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 7-language support (EN canonical + TR/ZH/HI/DE/FR/NL) to the GitHub Pages site via generated static HTML per language, with an SVG-flag dropdown, browser-language detection, and localStorage persistence.

**Architecture:** A zero-dependency Node build script renders a single tokenized HTML template per page against 7 JSON dictionaries, emitting English to `docs/` root and each other language to `docs/<lang>/`. A flag dropdown switches language by link; a tiny inline head script detects the browser language once and redirects; `<html lang>` + hreflang handle SEO.

**Tech Stack:** Vanilla HTML/CSS/JS, Node ≥18 (`node:fs`, `node:test`), GitHub Pages (`.nojekyll`, static output). No runtime dependencies, no client framework.

**Spec:** [`docs/superpowers/specs/2026-06-27-site-multilanguage-design.md`](../specs/2026-06-27-site-multilanguage-design.md)

---

## File Structure

**Source (edited here):**
- `docs-src/index.html` — landing template (tokens, no literal copy)
- `docs-src/docs.html` — docs template (tokens)
- `docs-src/i18n/{en,tr,zh,hi,de,fr,nl}.json` — dictionaries (copy only; no computed keys)
- `docs-src/detect.js` — canonical browser-language detection script (inlined into every page head)
- `docs-src/flags/{en,tr,zh,hi,de,fr,nl}.svg` — inline flag SVGs

**Build (logic, tested):**
- `scripts/build-site.js` — renderer + orchestrator (ESM, zero-dep)
- `scripts/build-site.test.js` — `node:test` unit tests

**Output (generated, committed, served by Pages):**
- `docs/index.html`, `docs/docs.html` — English (root, existing URLs preserved)
- `docs/tr/{index,docs}.html`, plus `zh/`, `hi/`, `de/`, `fr/`, `nl/`
- `docs/site.css` — edited in place (selector styles + font stack); referenced absolutely
- `docs/favicon.ico`, `docs/.nojekyll` — untouched

## Conventions (apply everywhere)

1. **Token brace rule:**
   - `{{key}}` → HTML-escaped value. Use when the string is plain text (the engine escapes `& < > "`). Store literal `&` in JSON.
   - `{{{key}}}` → raw HTML. Use **only** when the value contains inline tags (`<strong>`, `<em>`, `<a>`, `<code>`, `<br>`, `<span>`). Store real Unicode (em dash, curly quotes).
2. **Endonyms:** Language names in the dropdown are always endonyms (Türkçe, 中文, हिन्दी, Deutsch, Français, Nederlands, English) — literal in the template, **never** tokens.
3. **Untranslated (copied verbatim to all languages):** brand `review-pro`; all `<pre><code>` command blocks **including `#` comments**; pill labels that are proper nouns/keywords (reviewers, stacks, platforms); file paths; the **entire animated hero demo**; `GitHub`/`npm` labels; the copyright line.
4. **Internal links are relative** (uniform across EN root and subdirs): brand & Home → `index.html`; Docs → `docs.html`; How/Capabilities → `index.html#how` / `index.html#capabilities`; Install → `docs.html#install`; manual-install ref → `docs.html#manual-install`. The build does **not** compute per-page/per-lang links.
5. **Cross-language + assets are absolute:** dropdown `<a href="/review-pro/<lang>/">`; `<link rel="stylesheet" href="/review-pro/site.css">` (shared single copy); favicon stays inline data-URI.
6. **Per-page variance is minimal:** only `<html lang="{{lang}}">` differs between languages. Everything else is identical on every page and parametrized at runtime by `document.documentElement.lang`.
7. **Computed (non-translated) keys injected by the build at render time** (not present in JSON, excluded from parity): `lang`, `code` (UPPERCASE), `flag.current`, `flag.en`…`flag.nl` (inline SVG strings).

---

## Task 1: Build engine — token replacement (TDD)

**Files:**
- Create: `scripts/build-site.js`
- Create: `scripts/build-site.test.js`

- [ ] **Step 1: Write the failing tests**

`scripts/build-site.test.js`:
```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { escapeHtml, renderTemplate } from './build-site.js';

test('escapeHtml escapes & < > "', () => {
  assert.equal(escapeHtml('a & <b> "c"'), 'a &amp; &lt;b&gt; &quot;c&quot;');
});

test('renderTemplate replaces {{key}} with escaped value', () => {
  assert.equal(renderTemplate('<p>{{x}}</p>', { x: 'a & b' }), '<p>a &amp; b</p>');
});

test('renderTemplate replaces {{{key}}} with raw value', () => {
  assert.equal(renderTemplate('<p>{{{x}}}</p>', { x: '<strong>y</strong>' }), '<p><strong>y</strong></p>');
});

test('raw takes precedence over escaped for same key', () => {
  assert.equal(renderTemplate('{{{x}}} {{x}}', { x: '<i/>' }), '<i/> &lt;i/&gt;');
});

test('renderTemplate throws on missing key (strict)', () => {
  assert.throws(() => renderTemplate('{{nope}}', {}), /Missing i18n key: nope/);
});

test('renderTemplate leaves non-token content untouched', () => {
  const t = '<code>npx review-pro init</code> {{x}}';
  assert.equal(renderTemplate(t, { x: 'hi' }), '<code>npx review-pro init</code> hi');
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `node --test scripts/build-site.test.js`
Expected: FAIL — `Cannot find module ./build-site.js`.

- [ ] **Step 3: Implement the engine core**

`scripts/build-site.js`:
```js
// Site i18n build: render tokenized templates against per-language dictionaries.
// Zero dependencies. Node >= 18. ESM.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join, dirname, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');

export const SUPPORTED = ['en', 'tr', 'zh', 'hi', 'de', 'fr', 'nl'];
export const BASE = '/review-pro'; // GitHub Pages base path

export function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// Replace {{{key}}} (raw) first, then {{key}} (escaped). Throws on missing key.
export function renderTemplate(tmpl, dict) {
  const rawRe = /\{\{\{\s*([\w.-]+)\s*\}\}\}/g;
  const escRe = /\{\{\s*([\w.-]+)\s*\}\}/g;
  const val = (key) => {
    if (!(key in dict)) throw new Error(`Missing i18n key: ${key}`);
    return dict[key];
  };
  let out = tmpl.replace(rawRe, (_, k) => val(k));
  out = out.replace(escRe, (_, k) => escapeHtml(val(k)));
  return out;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `node --test scripts/build-site.test.js`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/build-site.js scripts/build-site.test.js
git commit -m "feat(site): i18n build engine — token replacement"
```

---

## Task 2: Build engine — config, parity, no-leftover, context merge (TDD)

**Files:**
- Modify: `scripts/build-site.js`
- Modify: `scripts/build-site.test.js`

- [ ] **Step 1: Write the failing tests**

Append to `scripts/build-site.test.js`:
```js
import { assertParity, assertNoTokens, buildContext } from './build-site.js';

test('assertParity passes when keys match', () => {
  assertParity({ a: '1', b: '2' }, { a: 'x', b: 'y' }, 'tr'); // does not throw
});

test('assertParity throws listing missing keys', () => {
  assert.throws(
    () => assertParity({ a: '1', b: '2' }, { a: 'x' }, 'tr'),
    /tr.*missing.*b/i
  );
});

test('assertNoTokens throws on leftover braces', () => {
  assert.throws(() => assertNoTokens('hi {{x}}', 'tr', 'index.html'), /Unrendered token/);
  assert.doesNotThrow(() => assertNoTokens('clean', 'en', 'index.html'));
});

test('buildContext merges copy + computed keys', () => {
  const ctx = buildContext({
    lang: 'tr',
    copy: { 'nav.how': 'Nasil' },
    flags: { tr: '<svg id="tr"/>', en: '<svg id="en"/>' },
  });
  assert.equal(ctx.lang, 'tr');
  assert.equal(ctx.code, 'TR');
  assert.equal(ctx['nav.how'], 'Nasil');
  assert.equal(ctx['flag.current'], '<svg id="tr"/>');
  assert.equal(ctx['flag.en'], '<svg id="en"/>');
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `node --test scripts/build-site.test.js`
Expected: FAIL — `assertParity` etc. not exported.

- [ ] **Step 3: Implement config + helpers**

Append to `scripts/build-site.js`:
```js
// --- Config / helpers ---

export function assertParity(reference, candidate, lang) {
  const missing = Object.keys(reference).filter((k) => !(k in candidate));
  if (missing.length) {
    throw new Error(`i18n parity error [${lang}] missing keys: ${missing.join(', ')}`);
  }
}

export function assertNoTokens(rendered, lang, page) {
  if (/\{\{|\}\}/.test(rendered)) {
    throw new Error(`Unrendered token in ${lang}/${page}`);
  }
}

// Merge translator copy with computed (non-translated) keys for renderTemplate.
export function buildContext({ lang, copy, flags }) {
  const ctx = { ...copy, lang, code: lang.toUpperCase() };
  for (const code of SUPPORTED) ctx[`flag.${code}`] = flags[code];
  ctx['flag.current'] = flags[lang];
  return ctx;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `node --test scripts/build-site.test.js`
Expected: PASS (10 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/build-site.js scripts/build-site.test.js
git commit -m "feat(site): i18n build — parity, no-leftover, context merge"
```

---

## Task 3: Build engine — orchestrate buildAll (TDD)

**Files:**
- Modify: `scripts/build-site.js`
- Modify: `scripts/build-site.test.js`

- [ ] **Step 1: Write the failing test**

Append to `scripts/build-site.test.js`:
```js
import { rmSync } from 'node:fs';
import { buildAll } from './build-site.js';

test('buildAll renders EN to root and others to subdirs, inlines detect + flags', () => {
  const tmp = join(process.cwd(), '.tmp-build-test');
  try {
    const src = join(tmp, 'src'), out = join(tmp, 'out');
    mkdirSync(join(src, 'i18n'), { recursive: true });
    mkdirSync(join(src, 'flags'), { recursive: true });
    writeFileSync(join(src, 'index.html'),
      '<html lang="{{lang}}"><head><script>/*DETECT*/</script></head>' +
      '<body>{{{flag.current}}} {{code}} {{nav.how}} <a href="/review-pro/">English</a></body></html>');
    writeFileSync(join(src, 'i18n', 'en.json'), JSON.stringify({ 'nav.how': 'How it works' }));
    writeFileSync(join(src, 'i18n', 'tr.json'), JSON.stringify({ 'nav.how': 'Nasil' }));
    writeFileSync(join(src, 'detect.js'), 'console.log("detect");');
    for (const l of ['en', 'tr']) writeFileSync(join(src, 'flags', `${l}.svg`), `<svg id="${l}"/>`);

    const written = buildAll({ srcDir: src, outDir: out, langs: ['en', 'tr'] });

    assert.deepEqual(written.sort(), [join(out, 'index.html'), join(out, 'tr', 'index.html')].sort());
    const en = readFileSync(join(out, 'index.html'), 'utf8');
    const tr = readFileSync(join(out, 'tr', 'index.html'), 'utf8');
    assert.match(en, /lang="en"/);
    assert.match(tr, /lang="tr"/);
    assert.ok(en.includes('How it works') && en.includes('<svg id="en"/>')); // flag inlined
    assert.ok(tr.includes('Nasil') && tr.includes('console.log("detect");')); // detect inlined
    assert.ok(!/\{\{/.test(en) && !/\{\{/.test(tr));
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});
```
(The test reuses `join`, `mkdirSync`, `readFileSync`, `writeFileSync` already imported at the top of the test file; add them to the existing `node:fs`/`node:path` imports if not present.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `node --test scripts/build-site.test.js`
Expected: FAIL — `buildAll` not exported.

- [ ] **Step 3: Implement buildAll**

Append to `scripts/build-site.js`:
```js
const PAGES = ['index.html', 'docs.html'];

function loadFlags(srcDir, langs) {
  const flags = {};
  for (const l of langs) {
    let svg = readFileSync(join(srcDir, 'flags', `${l}.svg`), 'utf8');
    svg = svg.replace(/<\?xml.*?\?>/g, '').trim(); // drop XML prolog for inline use
    flags[l] = svg;
  }
  return flags;
}

export function buildAll({ srcDir, outDir, langs = SUPPORTED }) {
  const copy = {};
  for (const l of langs) {
    copy[l] = JSON.parse(readFileSync(join(srcDir, 'i18n', `${l}.json`), 'utf8'));
  }
  for (const l of langs) {
    if (l !== 'en') assertParity(copy.en, copy[l], l); // translators can't drop keys
  }
  const detect = readFileSync(join(srcDir, 'detect.js'), 'utf8');
  const flags = loadFlags(srcDir, langs);

  const written = [];
  for (const l of langs) {
    for (const page of PAGES) {
      let tmpl = readFileSync(join(srcDir, page), 'utf8');
      tmpl = tmpl.replace('/*DETECT*/', () => detect); // inline detection script
      const ctx = buildContext({ lang: l, copy: copy[l], flags });
      const rendered = renderTemplate(tmpl, ctx);
      assertNoTokens(rendered, l, page);
      const outPath = l === 'en' ? join(outDir, page) : join(outDir, l, page);
      mkdirSync(dirname(outPath), { recursive: true });
      writeFileSync(outPath, rendered);
      written.push(outPath);
    }
  }
  return written;
}

// CLI entrypoint: `node scripts/build-site.js`
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const srcDir = join(ROOT, 'docs-src');
  const outDir = join(ROOT, 'docs');
  const written = buildAll({ srcDir, outDir });
  console.log(`site: wrote ${written.length} pages across ${SUPPORTED.length} languages -> ${relative(ROOT, outDir)}/`);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `node --test scripts/build-site.test.js`
Expected: PASS (11 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/build-site.js scripts/build-site.test.js
git commit -m "feat(site): i18n build — orchestrate buildAll + CLI entrypoint"
```

---

## Task 4: English dictionary (canonical source)

**Files:**
- Create: `docs-src/i18n/en.json`

- [ ] **Step 1: Write `docs-src/i18n/en.json`**

Single source of truth for every translatable string. Keys map 1:1 to their location. Values use real Unicode (em dash, curly quotes). A key whose value contains inline tags is referenced as `{{{key}}}` in the templates (Task 5/6); plain text as `{{key}}`.

```json
{
  "title": "review-pro — tiered AI code review",
  "meta.description": "review-pro reviews AI-written code in stages: triage dispatches the relevant specialists, each runs in its own scope, then synthesis returns one verdict. Built for the failure modes AI code ships with.",

  "nav.how": "How it works",
  "nav.capabilities": "Capabilities",
  "nav.docs": "Docs",
  "nav.install": "Install",

  "hero.eyebrow": "Tiered AI code review",
  "hero.title": "Twelve specialists.<br>One <em>verdict</em>.",
  "hero.sub": "review-pro reviews AI-written code in stages. Triage dispatches only the relevant specialists, each runs in its own scoped context, then synthesis returns one verdict. Built for the failure modes AI code actually ships with.",
  "hero.cta.install": "Install",
  "hero.cta.docs": "Read the docs",

  "pipeline.stage.label": "STAGE",
  "pipeline.s1.title": "Triage",
  "pipeline.s1.body": "Classify the diff and dispatch only the specialists that matter for this change. Each one gets scoped context — callers, repo search, schema, consumers — not the whole repository.",
  "pipeline.s1.tag1": "classify",
  "pipeline.s1.tag2": "scope",
  "pipeline.s1.tag3": "dispatch",
  "pipeline.s2.title": "Fan-out",
  "pipeline.s2.body": "The relevant specialists run in parallel. Twelve reviewers, each owns one concern, each returns structured, evidence-backed findings with file, line, impact, and remedy.",
  "pipeline.s2.tag1": "parallel",
  "pipeline.s2.tag2": "scoped",
  "pipeline.s2.tag3": "structured",
  "pipeline.s3.title": "Synthesis",
  "pipeline.s3.body": "Dedupe overlaps, resolve cross-reviewer conflicts by domain ownership, calibrate severity against over-reporting, and emit one verdict — <strong>BLOCK</strong>, <strong>REQUEST CHANGES</strong>, or <strong>APPROVE</strong>.",
  "pipeline.s3.tag1": "dedupe",
  "pipeline.s3.tag2": "resolve",
  "pipeline.s3.tag3": "verdict",

  "cap.eyebrow": "Capabilities",
  "cap.title": "A review bench, not one big guess.",
  "cap.lead": "Every specialist owns a single concern and a strict rubric. A first-class AI-anti-patterns lens catches what generic reviewers miss — hallucinated APIs, over-engineering, ignored helpers, needless dependencies.",
  "cap.c1.title": "12 specialist reviewers",
  "cap.c1.body": "Each owns one concern, with a strict, calibrated rubric and structured output.",
  "cap.c2.title": "14 stack packs",
  "cap.c2.body": "Language & framework signals layered onto the core rubrics at review time. Framework packs compose on a language pack.",
  "cap.c3.title": "4 platforms",
  "cap.c3.body": "One canonical source installs into each tool from a single command. Codex agents auto-transform to TOML; Cursor can <code>/add-plugin</code> the repo directly.",

  "install.eyebrow": "Install",
  "install.title": "One command. No lock-in.",
  "install.lead": "Install the core into your tool, then add the stack packs you use.",
  "install.note1": "No Node.js? review-pro is plain markdown skills and agents — copy them into your tool’s folder and it works the same. See the <a href=\"docs.html#manual-install\">manual install guide</a>.",
  "install.note2": "Then restart your tool and run a review — open a branch and ask the session to review it, or invoke the <span class=\"kbd\">review-pro</span> skill.",

  "footer.statement": "Code review that thinks in stages.",
  "footer.home": "Home",

  "docs.title": "Docs — review-pro",
  "docs.meta.description": "review-pro documentation: install, stack packs, commands, manual install, running a review.",

  "docs.toc.title": "On this page",
  "docs.toc.overview": "Overview",
  "docs.toc.install": "Install",
  "docs.toc.manual": "Manual install (no Node)",
  "docs.toc.stacks": "Stack packs",
  "docs.toc.commands": "Commands",
  "docs.toc.run": "Run a review",
  "docs.toc.reviewers": "The 12 reviewers",
  "docs.toc.faq": "FAQ",

  "docs.overview.h2": "Overview",
  "docs.overview.p1": "review-pro is a tiered AI code-review system: <strong>triage → relevant specialist reviewers → synthesis</strong>. It reviews code written by AI agents, using AI agents — built to catch the failure modes AI-generated code actually ships with: hallucinated APIs, over-engineering, ignored conventions, needless dependencies.",
  "docs.overview.p2": "This CLI installs the review-pro core (12 reviewer skills + subagents + the <code>review-pro</code> orchestrator) into your agent tool, and the stack packs into your repo’s <code>.review-pro/</code>. Supported targets: <strong>opencode · Claude Code · Cursor · Codex</strong>.",

  "docs.install.h2": "Install",
  "docs.install.p": "One-time. Interactive — it asks which platforms and which stack packs to install.",
  "docs.install.note": "Non-interactive (CI)? Use <code>--target &lt;platform|all|auto&gt;</code> and <code>--no-stacks</code>.",
  "docs.install.h3": "Per-platform notes",
  "docs.install.li1": "<strong>opencode</strong> — skills to <code>~/.config/opencode/skills/</code>, agents to <code>~/.config/opencode/agents/</code> (<code>$OPENCODE_HOME</code> overrides).",
  "docs.install.li2": "<strong>Claude Code</strong> — skills to <code>~/.claude/skills/</code>, agents to <code>~/.claude/agents/</code> (the agent <code>skills:</code> field preloads its rubric).",
  "docs.install.li3": "<strong>Cursor</strong> — installed via Cursor <code>/add-plugin</code>; run <code>/add-plugin https://github.com/tufantunc/review-pro</code> in Cursor (the repo ships a <code>.cursor-plugin/plugin.json</code>).",
  "docs.install.li4": "<strong>Codex</strong> — skills to <code>~/.agents/skills/</code>, agents auto-transformed to <code>~/.codex/agents/*.toml</code>. Codex auto-discovers skills; agents inherit the session skill set.",
  "docs.install.callout": "Then add the stack packs you use (below), <strong>restart your tool</strong> so the new skills/agents are discovered, and run a review.",

  "docs.manual.h2": "Manual install (no Node.js)",
  "docs.manual.p": "review-pro is plain markdown skills and agents — no runtime dependency. If you don’t have Node.js (or prefer not to use the CLI), copy the files by hand:",
  "docs.manual.ol1": "<strong>Core</strong> — copy <code>core/skills/&lt;name&gt;/</code> into your tool’s skills folder, and <code>core/agents/*.md</code> into its agents folder (paths per platform above).",
  "docs.manual.ol2": "<strong>Stack packs</strong> — copy <code>stacks/&lt;pack&gt;/</code> into the reviewed repo’s <code>.review-pro/&lt;pack&gt;/</code>.",
  "docs.manual.note": "The CLI just automates these copies (plus the Codex <code>.md</code>→<code>.toml</code> transform and version tracking). Manual and CLI installs are equivalent.",

  "docs.stacks.h2": "Stack packs",
  "docs.stacks.p": "Packs layer language/framework-specific signals onto the reviewers at review time. Install the ones a repo uses into its <code>.review-pro/</code>. Framework/domain packs compose on top of a language pack.",
  "docs.stacks.catalog": "Catalog (14): <code>python</code> · <code>go</code> · <code>rust</code> · <code>typescript-react</code> · <code>node</code> · <code>php</code> · <code>dotnet</code> · <code>kotlin</code> · <code>swift</code> · <code>flutter</code> · <code>nextjs</code> · <code>react-native</code> · <code>wordpress</code> · <code>ai-ml</code>. Examples: a Next.js repo activates <code>typescript-react</code> + <code>nextjs</code>; an LLM app activates <code>python</code> + <code>ai-ml</code>.",

  "docs.commands.h2": "Commands",
  "docs.commands.th1": "Command",
  "docs.commands.th2": "What it does",
  "docs.commands.r1": "Interactive — select stacks to install into <code>.review-pro/</code>",
  "docs.commands.r2": "Install the core plugin into a tool’s home",
  "docs.commands.r3": "Install one stack pack (non-interactive)",
  "docs.commands.r4": "Remove an installed pack",
  "docs.commands.r5": "Refresh installed packs to the catalog version",
  "docs.commands.r6": "Show catalog stacks + installed versions + drift",
  "docs.commands.r7": "Validate installed packs (version drift, roster integrity, orphans)",

  "docs.run.h2": "Run a review",
  "docs.run.p": "After install + restart, in the repo you want to review (on a feature branch):",
  "docs.run.li1": "ask the session to <strong>review this branch with review-pro</strong>, or",
  "docs.run.li2": "invoke the <strong><code>review-pro</code></strong> skill directly.",
  "docs.run.final": "The agent runs the whole pipeline natively — <code>git diff</code>, reads changed files, Globs <code>.review-pro/</code> for active stacks, dispatches the relevant reviewer subagents with their stack signals, and synthesizes one verdict: <strong>BLOCK / REQUEST CHANGES / APPROVE</strong>. No env vars, no scripts to run at review time.",

  "docs.reviewers.h2": "The 12 reviewers",
  "docs.reviewers.p": "<code>security</code> · <code>correctness</code> · <code>craft</code> · <code>ai-antipatterns</code> · <code>dry</code> · <code>performance</code> · <code>backend</code> · <code>frontend</code> · <code>a11y</code> · <code>db</code> · <code>api-contract</code> · <code>tests</code>. The <code>ai-antipatterns</code> reviewer is first-class: hallucinated APIs/symbols/imports, invented config/env keys, needless dependencies, and ignored existing helpers.",

  "docs.faq.h2": "FAQ",
  "docs.faq.q1": "Does it need Node.js?",
  "docs.faq.a1": "Only the installer CLI does (Node ≥ 18). The plugin itself is plain markdown skills and agents, so <a href=\"#manual-install\">manual install</a> works without Node on any platform.",
  "docs.faq.q2": "How is this different from a single “review this” prompt?",
  "docs.faq.a2": "One prompt hands the whole diff to one agent and asks for everything. review-pro triages first, runs only the relevant specialists in parallel with scoped context, then synthesizes — so small changes stay cheap and large changes go deep, with severity calibrated against over-reporting.",
  "docs.faq.q3": "Where do stack packs come from?",
  "docs.faq.a3": "The catalog ships inside this package, snapshotted at publish time. New packs appear after a new version is published. See <code>stacks/CONTRIBUTING.md</code> in the repo to add your own.",
  "docs.faq.q4": "Is it really cross-platform?",
  "docs.faq.a4": "Yes — one canonical source installs into opencode, Claude Code, Cursor, and Codex. Codex agents are auto-transformed to TOML; the others consume the same markdown agents."
}
```

- [ ] **Step 2: Validate JSON parses**

Run: `node -e "JSON.parse(require('fs').readFileSync('docs-src/i18n/en.json','utf8')); console.log('en.json OK')"`
Expected: `en.json OK`

- [ ] **Step 3: Commit**

```bash
git add docs-src/i18n/en.json
git commit -m "feat(site): English i18n dictionary (canonical source)"
```

---

## Task 5: Landing template (`docs-src/index.html`)

**Files:**
- Create: `docs-src/index.html` (derived from current `docs/index.html`)

- [ ] **Step 1: Create the tokenized landing template**

Copy current `docs/index.html` to `docs-src/index.html`, then apply these transformations.

**A. `<head>` — replace the opening lines:**
```html
<!doctype html>
<html lang="{{lang}}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>{{title}}</title>
<meta name="description" content="{{meta.description}}">
<link rel="alternate" hreflang="en" href="https://tufantunc.github.io/review-pro/">
<link rel="alternate" hreflang="tr" href="https://tufantunc.github.io/review-pro/tr/">
<link rel="alternate" hreflang="zh" href="https://tufantunc.github.io/review-pro/zh/">
<link rel="alternate" hreflang="hi" href="https://tufantunc.github.io/review-pro/hi/">
<link rel="alternate" hreflang="de" href="https://tufantunc.github.io/review-pro/de/">
<link rel="alternate" hreflang="fr" href="https://tufantunc.github.io/review-pro/fr/">
<link rel="alternate" hreflang="nl" href="https://tufantunc.github.io/review-pro/nl/">
<link rel="alternate" hreflang="x-default" href="https://tufantunc.github.io/review-pro/">
<script>/*DETECT*/</script>
```
Keep the existing favicon `<link rel="icon" …>` and font `<link>`s. Change the stylesheet to absolute: `<link rel="stylesheet" href="/review-pro/site.css">`.

**B. `<nav>` — relative links + language selector:**
```html
<nav class="nav" aria-label="Primary">
  <a class="brand" href="index.html"><span class="brand__mark" aria-hidden="true"></span> review-pro</a>
  <div class="nav__links">
    <a href="index.html#how">{{nav.how}}</a>
    <a href="index.html#capabilities">{{nav.capabilities}}</a>
    <a class="nav__keep" href="docs.html">{{nav.docs}}</a>
    <a href="https://github.com/tufantunc/review-pro" target="_blank" rel="noopener">GitHub</a>
    <a class="nav__cta" href="docs.html#install">{{nav.install}}</a>
    <div class="lang">
      <button class="lang__btn" type="button" aria-haspopup="true" aria-expanded="false" aria-label="Language">
        {{{flag.current}}}<span class="lang__code">{{code}}</span>
      </button>
      <ul class="lang__menu" role="menu" hidden>
        <li role="none"><a role="menuitem" data-lang="en" href="/review-pro/">{{{flag.en}}} English</a></li>
        <li role="none"><a role="menuitem" data-lang="tr" href="/review-pro/tr/">{{{flag.tr}}} Türkçe</a></li>
        <li role="none"><a role="menuitem" data-lang="zh" href="/review-pro/zh/">{{{flag.zh}}} 中文</a></li>
        <li role="none"><a role="menuitem" data-lang="hi" href="/review-pro/hi/">{{{flag.hi}}} हिन्दी</a></li>
        <li role="none"><a role="menuitem" data-lang="de" href="/review-pro/de/">{{{flag.de}}} Deutsch</a></li>
        <li role="none"><a role="menuitem" data-lang="fr" href="/review-pro/fr/">{{{flag.fr}}} Français</a></li>
        <li role="none"><a role="menuitem" data-lang="nl" href="/review-pro/nl/">{{{flag.nl}}} Nederlands</a></li>
      </ul>
    </div>
  </div>
</nav>
```

**C. `<header class="hero">` — tokenize copy (keep the entire `<div class="demo reveal" id="demo">…</div>` block byte-identical, English):**
```html
<p class="eyebrow">{{hero.eyebrow}}</p>
<h1 class="hero__title">{{{hero.title}}}</h1>
<p class="hero__sub">{{hero.sub}}</p>
<div class="hero__cta">
  <a class="btn btn--primary" href="docs.html#install">{{hero.cta.install}}</a>
  <a class="btn" href="docs.html">{{hero.cta.docs}}</a>
</div>
```

**D. Pipeline section** (`<section class="pipeline wrap" id="how">`): for each of the 3 stages, replace title/body/tags. Stage 01:
```html
<div class="stage__num">01<span>{{pipeline.stage.label}}</span></div>
<div>
  <h2 class="stage__title">{{pipeline.s1.title}}</h2>
  <p class="stage__body">{{pipeline.s1.body}}</p>
  <div class="stage__tags"><span class="tag">{{pipeline.s1.tag1}}</span><span class="tag">{{pipeline.s1.tag2}}</span><span class="tag">{{pipeline.s1.tag3}}</span></div>
</div>
```
Stages 02/03 follow the same pattern with `s2`/`s3` keys. (`pipeline.s3.body` is referenced as `{{{pipeline.s3.body}}}` — raw, contains `<strong>`.)

**E. Capabilities section** — eyebrow/title/lead + 3 cards. Card 3 body is raw; others escaped:
```html
<p class="section__eyebrow">{{cap.eyebrow}}</p>
<h2 class="section__title">{{cap.title}}</h2>
<p class="section__lead">{{cap.lead}}</p>
…
<h3>{{cap.c1.title}}</h3><p>{{cap.c1.body}}</p>
<h3>{{cap.c2.title}}</h3><p>{{cap.c2.body}}</p>
<h3>{{cap.c3.title}}</h3><p>{{{cap.c3.body}}}</p>
```
All pill `<span class="tag">…</span>` content stays English (reviewer/stack/platform names).

**F. Install section** — code block unchanged; notes tokenized:
```html
<p class="section__eyebrow">{{install.eyebrow}}</p>
<h2 class="section__title" style="font-size:var(--text-xl);">{{install.title}}</h2>
<p class="section__lead" style="margin-bottom:0.2rem;">{{install.lead}}</p>
<pre class="cmd"><code>npx review-pro init            <span class="cmt"># interactive: pick platforms + stacks</span>
npx review-pro add <span class="prm">python</span>      <span class="cmt"># add a stack to .review-pro/</span></code></pre>
<p class="note">{{{install.note1}}}</p>
<p class="note">{{{install.note2}}}</p>
```

**G. Footer** — statement + Home/Docs links relative; GitHub/npm proper nouns stay:
```html
<footer class="footer wrap">
  <div class="footer__top">
    <p class="footer__statement">{{footer.statement}}</p>
    <div class="footer__links">
      <a href="index.html">{{footer.home}}</a>
      <a href="docs.html">{{nav.docs}}</a>
      <a href="https://github.com/tufantunc/review-pro" target="_blank" rel="noopener">GitHub</a>
      <a href="https://www.npmjs.com/package/review-pro" target="_blank" rel="noopener">npm</a>
    </div>
  </div>
  <p class="footer__copy">MIT · review-pro · <a href="https://github.com/tufantunc/review-pro" style="color:inherit">github.com/tufantunc/review-pro</a></p>
</footer>
```

**H. Selector script** — add this `<script>` block immediately before the closing `</body>` (after the existing demo `<script>`):
```html
<script>
  (function () {
    var btn = document.querySelector('.lang__btn');
    var menu = document.querySelector('.lang__menu');
    if (!btn || !menu) return;
    var cur = document.documentElement.lang;
    menu.querySelectorAll('a').forEach(function (a) {
      if (a.dataset.lang === cur) a.setAttribute('aria-current', 'true');
    });
    function open() { menu.hidden = false; btn.setAttribute('aria-expanded', 'true'); }
    function close() { menu.hidden = true; btn.setAttribute('aria-expanded', 'false'); }
    btn.addEventListener('click', function (e) { e.stopPropagation(); menu.hidden ? open() : close(); });
    document.addEventListener('click', function (e) { if (!menu.contains(e.target) && e.target !== btn) close(); });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') close(); });
    btn.addEventListener('keydown', function (e) {
      if (e.key === 'ArrowDown' || e.key === 'Enter' || e.key === ' ') {
        e.preventDefault(); open(); var f = menu.querySelector('a'); if (f) f.focus();
      }
    });
  })();
</script>
```

- [ ] **Step 2: Commit**

```bash
git add docs-src/index.html
git commit -m "feat(site): tokenized landing template + language selector"
```

---

## Task 6: Docs template (`docs-src/docs.html`)

**Files:**
- Create: `docs-src/docs.html` (derived from current `docs/docs.html`)

- [ ] **Step 1: Create the tokenized docs template**

Copy current `docs/docs.html` to `docs-src/docs.html`, then apply the **same** head/nav/footer treatment as Task 5 (hreflang block, `/*DETECT*/` script tag, absolute stylesheet `/review-pro/site.css`, `<html lang="{{lang}}">`, the identical `<nav>` with selector markup, relative internal links, the selector `<script>` before `</body>`). Keep the existing TOC-scroll IntersectionObserver `<script>` unchanged. Then tokenize every translatable node:

- `<title>{{docs.title}}</title>`; `<meta name="description" content="{{docs.meta.description}}">`
- TOC: `<p class="toc__title">{{docs.toc.title}}</p>` and each `<li><a href="#…">{{docs.toc.<section>}}</a></li>` for `overview`, `install`, `manual`, `stacks`, `commands`, `run`, `reviewers`, `faq`.
- Overview: `<h2 id="overview">{{docs.overview.h2}}</h2>`, then `{{{docs.overview.p1}}}` and `{{{docs.overview.p2}}}` (raw).
- Install: `{{docs.install.h2}}`, `{{docs.install.p}}`, the `<pre class="cmd">` block **unchanged**, `{{{docs.install.note}}}`, `<h3>{{docs.install.h3}}</h3>`, the 4 `<li>` → `{{{docs.install.li1}}}`…`{{{docs.install.li4}}}`, callout `{{{docs.install.callout}}}`.
- Manual install: `{{docs.manual.h2}}`, `{{docs.manual.p}}`, the 2 `<li>` → `{{{docs.manual.ol1}}}`, `{{{docs.manual.ol2}}}`, the `<pre class="cmd">` block **unchanged**, `{{{docs.manual.note}}}`.
- Stack packs: `{{docs.stacks.h2}}`, `{{{docs.stacks.p}}}`, the `<pre class="cmd">` block **unchanged**, `{{{docs.stacks.catalog}}}`.
- Commands: `{{docs.commands.h2}}`, `<th>{{docs.commands.th1}}</th><th>{{docs.commands.th2}}</th>`, left `<td><code>…</code></td>` cells **unchanged**, right cells → `{{{docs.commands.r1}}}` (raw) then `{{docs.commands.r2}}`…`{{docs.commands.r7}}` (escaped). Keep existing `tr`/`td` structure.
- Run a review: `{{docs.run.h2}}`, `{{docs.run.p}}`, `{{{docs.run.li1}}}`, `{{{docs.run.li2}}}`, `{{{docs.run.final}}}`.
- Reviewers: `{{docs.reviewers.h2}}`, `{{{docs.reviewers.p}}}`.
- FAQ: `{{docs.faq.h2}}`, then `<h3>{{docs.faq.q1}}</h3><p>{{{docs.faq.a1}}}</p>` … `<h3>{{docs.faq.q4}}</h3><p>{{docs.faq.a4}}</p>` (a1/a3 raw; a2/a4 escaped — a2 has curly quotes, escaped).

**Nav links (docs page):** brand → `index.html`; How → `index.html#how`; Capabilities → `index.html#capabilities`; Docs → `docs.html` (keep `is-active`); Install → `docs.html#install`; Home (footer) → `index.html`.

- [ ] **Step 2: Commit**

```bash
git add docs-src/docs.html
git commit -m "feat(site): tokenized docs template"
```

---

## Task 7: Detection script + flag SVGs

**Files:**
- Create: `docs-src/detect.js`
- Create: `docs-src/flags/{en,tr,zh,hi,de,fr,nl}.svg`

- [ ] **Step 1: Write the detection script**

`docs-src/detect.js` (inlined verbatim into every page head; parametrized by `<html lang>` and the constant base `/review-pro`):
```js
(function () {
  try {
    var KEY = 'rp_lang';
    if (localStorage.getItem(KEY)) return;           // user already chose
    if (navigator.webdriver) return;                 // automation
    var ua = navigator.userAgent || '';
    if (/bot|crawl|spider|slurp|headless|wget|curl|lighthouse|pingdom/i.test(ua)) return;
    var supported = ['en', 'tr', 'zh', 'hi', 'de', 'fr', 'nl'];
    var cur = document.documentElement.lang;
    var picks = navigator.languages && navigator.languages.length ? navigator.languages : [navigator.language];
    var match = null;
    for (var i = 0; i < picks.length; i++) {
      var short = String(picks[i] || '').toLowerCase().split('-')[0];
      if (supported.indexOf(short) >= 0) { match = short; break; }
    }
    if (match && match !== cur) {
      var base = '/review-pro';
      var rel = location.pathname.replace(base, '').replace(/\/index\.html$/, '/');
      rel = rel.replace(/^\/(en|tr|zh|hi|de|fr|nl)(\/|$)/, '/');
      rel = rel.replace(/\/+$/, '/');
      var target = base + '/' + match + (rel === '/' ? '/' : rel);
      target = target.replace(/\/{2,}/g, '/');
      localStorage.setItem(KEY, match);
      location.replace(target);
    } else {
      localStorage.setItem(KEY, cur);
    }
  } catch (e) {}
})();
```

- [ ] **Step 2: Create the 7 flag SVGs**

Each is a `viewBox="0 0 60 40"` public-domain flag, **without** an XML prolog (the build strips it anyway). Author accurate standard geometry by adapting public-domain SVG path data (e.g. Wikimedia Commons flag SVGs, rescaled to the 60×40 viewBox). Do **not** invent incorrect geometry. Set each flag's `aria-label` to the endonym (English / Türkçe / 中文 / हिन्दी / Deutsch / Français / Nederlands).

- `docs-src/flags/en.svg` — United Kingdom (Union Jack), 3:2. (English has no single flag; UK is the conventional choice per the spec.)
- `docs-src/flags/tr.svg` — Turkey (red field, white crescent + star).
- `docs-src/flags/zh.svg` — China (red field, one large + four small yellow stars, canton top-left).
- `docs-src/flags/hi.svg` — India (saffron/white/green horizontal tricolor, navy 24-spoke chakra centred on white).
- `docs-src/flags/de.svg` — Germany (black/red/gold horizontal tricolor).
- `docs-src/flags/fr.svg` — France (blue/white/red vertical tricolor).
- `docs-src/flags/nl.svg` — Netherlands (red/white/blue horizontal tricolor).

Skeleton:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 60 40" role="img" aria-label="English">
  <rect width="60" height="40" fill="#012169"/>
  <!-- flag-specific paths -->
</svg>
```

- [ ] **Step 3: Commit**

```bash
git add docs-src/detect.js docs-src/flags
git commit -m "feat(site): browser-lang detection script + flag SVGs"
```

---

## Task 8: Selector CSS + font stack

**Files:**
- Modify: `docs/site.css` (edited in place; referenced absolutely from all pages)

- [ ] **Step 1: Append selector styles**

Append to `docs/site.css` (uses existing palette CSS vars `--color-paper`, `--color-paper-2`, `--color-ink`, `--color-ink-soft`, `--color-accent`, `--color-border`):
```css
/* Language selector */
.lang { position: relative; margin-left: 0.4rem; }
.lang__btn {
  display: inline-flex; align-items: center; gap: 0.35rem;
  padding: 0.3rem 0.5rem; border: 1px solid var(--color-border);
  background: var(--color-paper); border-radius: 8px;
  color: var(--color-ink-soft); font: inherit; font-size: 0.85rem;
  cursor: pointer; line-height: 1;
}
.lang__btn:hover { color: var(--color-ink); background: var(--color-paper-2); }
.lang__btn:focus-visible { outline: 2px solid var(--color-accent); outline-offset: 1px; }
.lang__flag { width: 20px; height: auto; border-radius: 2px; display: block; }
.lang__menu .lang__flag { width: 18px; }
.lang__code { font-weight: 600; letter-spacing: 0.02em; }
.lang__menu {
  position: absolute; right: 0; top: calc(100% + 4px); z-index: 50;
  list-style: none; margin: 0; padding: 0.3rem; min-width: 11rem;
  background: var(--color-paper); border: 1px solid var(--color-border);
  border-radius: 10px; box-shadow: 0 8px 24px rgba(0,0,0,0.12);
}
.lang__menu a {
  display: flex; align-items: center; gap: 0.5rem;
  padding: 0.4rem 0.5rem; border-radius: 6px;
  color: var(--color-ink-soft); text-decoration: none; font-size: 0.9rem;
}
.lang__menu a:hover { background: var(--color-paper-2); color: var(--color-ink); }
.lang__menu a:focus-visible { outline: 2px solid var(--color-accent); outline-offset: 1px; }
.lang__menu a[aria-current="true"] { color: var(--color-accent); font-weight: 600; }
```

- [ ] **Step 2: Extend the font stack (Hindi/Chinese fallback)**

Find every `font-family` that uses IBM Plex Sans / the body stack and append Devanagari + Simplified-Chinese fallbacks, e.g. change:
```css
font-family: "IBM Plex Sans", system-ui, sans-serif;
```
to:
```css
font-family: "IBM Plex Sans", system-ui, "Noto Sans Devanagari", "Noto Sans SC", sans-serif;
```

- [ ] **Step 3: Keep the selector visible on phones**

The `.lang` selector is a `<div>`, so it is already exempt from the existing `.nav__links a:not(.nav__cta):not(.nav__keep) { display: none; }` rule. Inside the existing `@media (max-width: 640px)` block add:
```css
.lang__code { display: none; }   /* phones: flag only */
```

- [ ] **Step 4: Commit**

```bash
git add docs/site.css
git commit -m "feat(site): language selector styles + Devanagari/CJK font fallback"
```

---

## Task 9: First full build — English only, verify parity vs current

**Files:**
- Generated: `docs/index.html`, `docs/docs.html` (overwrites current English files)

- [ ] **Step 1: Build English only (temporary langs override)**

Run a one-off to verify the English output before authoring other languages:
```bash
node --input-type=module -e "import {buildAll} from './scripts/build-site.js'; buildAll({srcDir:'docs-src',outDir:'docs',langs:['en']}); console.log('built EN');"
```
Expected: `built EN` (no errors → no missing keys, no leftover tokens).

- [ ] **Step 2: Verify no leftover tokens**

Run: `grep -RnE '\{\{|\}\}' docs/index.html docs/docs.html`
Expected: no matches (exit code 1).

- [ ] **Step 3: Eyeball the English diff**

Run: `git diff --stat docs/index.html docs/docs.html`
Expected: small diff (link normalisation to relative, added selector/hreflang/detect). Open `docs/index.html` in a browser; confirm the landing renders identically, the demo still animates, and the flag selector (showing the GB flag + "EN") appears in the nav and opens the dropdown.

- [ ] **Step 4: Commit generated English**

```bash
git add docs/index.html docs/docs.html
git commit -m "feat(site): generate English site from template (i18n baseline)"
```

---

## Tasks 10–12: Non-English dictionaries (content authoring)

These three tasks author the six non-English dictionaries. Each file must contain **exactly** the same keys as `docs-src/i18n/en.json` (Task 4) — the build's `assertParity` enforces this and the build fails if any key is missing. Values are natural translations; keep all inline HTML tags (`<strong>`, `<code>`, `<a>`, etc.) intact at the right place in the translated sentence, keep brand `review-pro` and code/paths untranslated, and use real Unicode punctuation appropriate to the language.

**Shared rule for every dictionary:** a key whose en.json value contains inline tags must keep those tags in the translation (it is referenced as `{{{key}}}` in the template); plain-text keys stay plain. Match the brace style implied by en.json — do not add or remove tags.

> The translation *values* are authored at execution time (marketing copy in each language) and reviewed by the user, with Turkish getting particular attention. The key set is fully determined by en.json; correctness is guaranteed structurally by the parity test, not by reproducing 600 strings in this plan.

### Task 10: Turkish + German

**Files:**
- Create: `docs-src/i18n/tr.json`
- Create: `docs-src/i18n/de.json`

- [ ] **Step 1: Author `tr.json`** — translate every en.json key to Turkish.

- [ ] **Step 2: Author `de.json`** — translate every en.json key to German.

- [ ] **Step 3: Verify parity (build must pass)**

Run: `node --input-type=module -e "import {buildAll} from './scripts/build-site.js'; buildAll({srcDir:'docs-src',outDir:'docs',langs:['en','tr','de']});"`
Expected: no parity errors, no leftover tokens (a throw lists any missing key).

- [ ] **Step 4: Commit**

```bash
git add docs-src/i18n/tr.json docs-src/i18n/de.json
git commit -m "feat(site): Turkish + German dictionaries"
```

### Task 11: French + Dutch

**Files:**
- Create: `docs-src/i18n/fr.json`
- Create: `docs-src/i18n/nl.json`

- [ ] **Step 1: Author `fr.json`** — translate every en.json key to French.

- [ ] **Step 2: Author `nl.json`** — translate every en.json key to Dutch.

- [ ] **Step 3: Verify parity**

Run: `node --input-type=module -e "import {buildAll} from './scripts/build-site.js'; buildAll({srcDir:'docs-src',outDir:'docs',langs:['en','tr','de','fr','nl']});"`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add docs-src/i18n/fr.json docs-src/i18n/nl.json
git commit -m "feat(site): French + Dutch dictionaries"
```

### Task 12: Chinese (Simplified) + Hindi

**Files:**
- Create: `docs-src/i18n/zh.json`
- Create: `docs-src/i18n/hi.json`

- [ ] **Step 1: Author `zh.json`** — translate every en.json key to Simplified Chinese.

- [ ] **Step 2: Author `hi.json`** — translate every en.json key to Hindi (Devanagari).

- [ ] **Step 3: Verify parity**

Run: `node scripts/build-site.js`
Expected: `site: wrote 14 pages across 7 languages -> docs/` with no errors (all 7 languages now build).

- [ ] **Step 4: Commit**

```bash
git add docs-src/i18n/zh.json docs-src/i18n/hi.json
git commit -m "feat(site): Chinese + Hindi dictionaries"
```

---

## Task 13: Full build, manual verification, commit generated site

**Files:**
- Generated: all 14 pages under `docs/` (`index.html`, `docs.html`, and `tr/`,`zh/`,`hi/`,`de/`,`fr/`,`nl/` subdirs)

- [ ] **Step 1: Run the full build**

Run: `node scripts/build-site.js`
Expected: `site: wrote 14 pages across 7 languages -> docs/`.

- [ ] **Step 2: Verify no leftover tokens anywhere**

Run: `grep -RnE '\{\{|\}\}' docs` (exclude nothing)
Expected: no matches.

- [ ] **Step 3: Manual browser pass (open `docs/index.html` via a local server)**

Serve: `python3 -m http.server 8080 --directory docs` then open `http://localhost:8080/`. For each language (click each flag in the dropdown):
- Copy is translated; nav, hero, sections, footer, and docs.html are translated.
- The animated hero demo stays **English** in every language.
- All `<pre><code>` commands and pill labels (reviewers/stacks/platforms) stay English.
- Home ↔ Docs navigation stays within the same language.
- The dropdown button shows the current flag + code; the current language's menu item is highlighted (`aria-current`).
- Hindi and Chinese render (system/Noto fallback); layout is not broken.

- [ ] **Step 4: Verify detection (DevTools)**

In DevTools → Application → Local storage, delete `rp_lang`. Override language via Sensors/Network conditions or `Intl` override to e.g. `de-DE`; reload `http://localhost:8080/` → expect a one-time redirect to `/de/`. Reload again → stays (no loop). Re-set `rp_lang`; switching via dropdown persists across reloads.

- [ ] **Step 5: Lighthouse a11y on `en` and `tr` landing**

Run Lighthouse (Accessibility) on `docs/index.html` and `docs/tr/index.html`.
Expected: selector is keyboard-operable (Tab to button → Enter/ArrowDown opens → arrow/Tab through items → Enter activates → Escape closes); no contrast/ARIA errors introduced by the selector.

- [ ] **Step 6: Verify SEO tags**

Run: `grep -Rn 'hreflang' docs/index.html docs/tr/index.html` and confirm `<html lang="…">` per page.
Expected: 8 hreflang links per page; `lang` matches each page's language.

- [ ] **Step 7: Commit the generated site**

```bash
git add docs
git commit -m "feat(site): build all 7 language versions of the site"
```

---

## Task 14: CI wiring + docs note

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify: `RELEASING.md`

- [ ] **Step 1: Add site build test + sync check to CI**

In `.github/workflows/ci.yml`, after the existing "Validator" step, add:
```yaml
      - name: Site i18n build (tests + sync)
        run: |
          node --test scripts/build-site.test.js
          node scripts/build-site.js
          git diff --exit-code docs
```
The `git diff --exit-code docs` fails CI if the committed `docs/` is out of sync with `docs-src/` (prevents drift).

- [ ] **Step 2: Document the build step in RELEASING.md**

Add a short "Site" section to `RELEASING.md`:
```markdown
## Site

The marketing/docs site under `docs/` is generated from `docs-src/`
(template + `i18n/*.json`). After editing source, rebuild and commit the output:

    node scripts/build-site.js
    git add docs
```

- [ ] **Step 3: Run the CI commands locally to confirm they pass**

Run: `node --test scripts/build-site.test.js && node scripts/build-site.js && git diff --exit-code docs`
Expected: tests pass; build writes 14 pages; `git diff --exit-code docs` passes (no diff — already committed in Task 13). If it reports a diff, re-run `git add docs` and amend.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml RELEASING.md
git commit -m "ci(site): test + sync-check the i18n build; document build step"
```

---

## Self-Review (plan author)

**Spec coverage:** every spec section maps to a task — architecture/File structure (Conventions + Tasks 1-3), URL structure & cross-page nav (Conventions §4-5 + Tasks 5-6), detection & persistence (Task 7 detect.js + Task 13 Step 4), templating/token rule (Conventions §1 + Tasks 1-3 engine), language selector (Tasks 5 markup + 8 CSS + selector script), SEO lang/hreflang (Tasks 5-6 head), fonts (Task 8 Step 2), translation scope (Conventions §3 + Task 4 + Tasks 10-12), build tooling (Tasks 1-3), risks (assertNoTokens, parity, absolute CSS — Tasks 2-3, 8), verification (Task 13). No gaps.

**Placeholder scan:** the only intentionally-author-at-execution content is the six translation dictionaries (Tasks 10-12) and the seven flag SVG geometries (Task 7 Step 2) — both are authored content (not logic), fully constrained by the en.json key set + parity test and by accurate public-domain flag geometry respectively. en.json is complete and literal. No "TBD"/"implement later"/"add error handling" anywhere.

**Type/name consistency:** `renderTemplate`, `escapeHtml`, `assertParity`, `assertNoTokens`, `buildContext`, `buildAll`, `SUPPORTED`, `BASE` are defined in Task 1-3 and referenced consistently in tests and CLI. Template tokens (`{{lang}}`, `{{code}}`, `{{{flag.current}}}`, `{{{flag.en}}}` …) match `buildContext`'s injected keys. `/*DETECT*/` placeholder string matches in template (Tasks 5-6) and `buildAll` (Task 3).

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-06-27-site-multilanguage.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

**Which approach?**
