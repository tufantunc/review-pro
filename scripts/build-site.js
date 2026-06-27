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
