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
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

// Replace {{{key}}} (raw) first, then {{key}} (escaped). Throws on missing key.
export function renderTemplate(tmpl, dict) {
  const rawRe = /\{\{\{\s*([\w.-]+)\s*\}\}\}/g;
  const escRe = /\{\{\s*([\w.-]+)\s*\}\}/g;
  const val = (key) => {
    if (!Object.hasOwn(dict, key)) throw new Error(`Missing i18n key: ${key}`);
    return dict[key];
  };
  let out = tmpl.replace(rawRe, (_, k) => val(k));
  out = out.replace(escRe, (_, k) => escapeHtml(val(k)));
  return out;
}

// --- Config / helpers ---

export function assertParity(reference, candidate, lang) {
  const missing = Object.keys(reference).filter((k) => !(k in candidate));
  if (missing.length) {
    throw new Error(`i18n parity error [${lang}] missing keys: ${missing.join(', ')}`);
  }
}

export function assertNoTokens(rendered, lang, page) {
  // Match only real token syntax ({{key}} / {{{key}}}), not stray braces in inline JS or code samples.
  if (/\{\{\{?\s*[\w.-]+\s*\}?\}\}/.test(rendered)) {
    throw new Error(`Unrendered token in ${lang}/${page}`);
  }
}

// Merge translator copy with computed (non-translated) keys for renderTemplate.
const NOTO = {
  hi: '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Sans+Devanagari:wght@400;500;600&display=swap">',
  zh: '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Sans+SC:wght@400;500;600&display=swap">',
};
export function buildContext({ lang, copy, flags }) {
  const ctx = { ...copy, lang, code: lang.toUpperCase() };
  for (const code of SUPPORTED) ctx[`flag.${code}`] = flags[code];
  ctx['flag.current'] = flags[lang];
  ctx['fonts_noto'] = NOTO[lang] || ''; // load Devanagari/CJK only on the pages that need them
  return ctx;
}

const PAGES = ['index.html', 'docs.html'];

function loadFlags(srcDir, langs) {
  const flags = {};
  for (const l of langs) {
    let svg = readFileSync(join(srcDir, 'flags', `${l}.svg`), 'utf8');
    svg = svg.replace(/<\?xml.*?\?>/g, '').trim(); // drop XML prolog for inline use
    // Flags are decorative where inlined (a text label is always present);
    // strip the standalone role/label and hide from AT.
    svg = svg.replace(/<svg\b([^>]*)>/, (_, attrs) => {
      const a = attrs.replace(/\s*role="img"/g, '').replace(/\s*aria-label="[^"]*"/g, '');
      return `<svg aria-hidden="true" focusable="false"${a}>`;
    });
    flags[l] = svg;
  }
  return flags;
}

export function buildAll({ srcDir, outDir, langs = SUPPORTED }) {
  if (!langs.includes('en')) {
    throw new Error("buildAll: 'en' must be included in langs (parity reference)");
  }
  const copy = {};
  for (const l of langs) {
    copy[l] = JSON.parse(readFileSync(join(srcDir, 'i18n', `${l}.json`), 'utf8'));
  }
  for (const l of langs) {
    if (l !== 'en') assertParity(copy.en, copy[l], l); // translators can't drop keys
  }
  // detect.js is rendered through the same engine so SUPPORTED/BASE flow from one source.
  const detect = renderTemplate(readFileSync(join(srcDir, 'detect.js'), 'utf8'), {
    supported_list: JSON.stringify(SUPPORTED),
    base: BASE,
  });
  const langMenu = readFileSync(join(srcDir, 'lang-menu.js'), 'utf8');
  const flags = loadFlags(srcDir, SUPPORTED); // flags are a shared set; every page's dropdown needs all 7

  const written = [];
  for (const l of langs) {
    for (const page of PAGES) {
      let tmpl = readFileSync(join(srcDir, page), 'utf8');
      tmpl = tmpl.replace('/*DETECT*/', () => detect);
      tmpl = tmpl.replace('/*LANGMENU*/', () => langMenu);
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
