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
