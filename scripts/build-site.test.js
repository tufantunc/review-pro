import { test } from 'node:test';
import assert from 'node:assert/strict';
import { rmSync, readFileSync, writeFileSync, mkdirSync, mkdtempSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { escapeHtml, renderTemplate, assertParity, assertNoTokens, buildContext, buildAll, SUPPORTED } from './build-site.js';

// --- escapeHtml ---
test('escapeHtml escapes & < > " and \'', () => {
  assert.equal(escapeHtml('a & <b> "c" \'d\''), 'a &amp; &lt;b&gt; &quot;c&quot; &#39;d&#39;');
});

// --- renderTemplate ---
test('renderTemplate replaces {{key}} with escaped value', () => {
  assert.equal(renderTemplate('<p>{{x}}</p>', { x: 'a & b' }), '<p>a &amp; b</p>');
});
test('renderTemplate replaces {{{key}}} with raw value', () => {
  assert.equal(renderTemplate('<p>{{{x}}}</p>', { x: '<strong>y</strong>' }), '<p><strong>y</strong></p>');
});
test('raw takes precedence over escaped for same key', () => {
  assert.equal(renderTemplate('{{{x}}} {{x}}', { x: '<i/>' }), '<i/> &lt;i/&gt;');
});
test('renderTemplate throws on missing key', () => {
  assert.throws(() => renderTemplate('{{nope}}', {}), /Missing i18n key: nope/);
});
test('renderTemplate leaves non-token content untouched', () => {
  assert.equal(renderTemplate('<code>npx review-pro init</code> {{x}}', { x: 'hi' }), '<code>npx review-pro init</code> hi');
});
test('renderTemplate throws on prototype-inherited keys', () => {
  assert.throws(() => renderTemplate('{{toString}}', {}), /Missing i18n key: toString/);
});
test('renderTemplate supports dotted keys and whitespace tolerance', () => {
  assert.equal(renderTemplate('{{ nav.how }}', { 'nav.how': 'How it works' }), 'How it works');
});

// --- assertParity (one-directional by design: EN is the reference) ---
test('assertParity passes when keys match', () => {
  assert.doesNotThrow(() => assertParity({ a: '1', b: '2' }, { a: 'x', b: 'y' }, 'tr'));
});
test('assertParity throws listing missing keys', () => {
  assert.throws(() => assertParity({ a: '1', b: '2' }, { a: 'x' }, 'tr'), /tr.*missing.*b/i);
});
test('assertParity tolerates extra keys in candidate', () => {
  assert.doesNotThrow(() => assertParity({ a: '1' }, { a: 'x', extra: 'y' }, 'tr'));
});

// --- assertNoTokens (scoped to real token syntax, not stray braces) ---
test('assertNoTokens throws on real token syntax', () => {
  assert.throws(() => assertNoTokens('hi {{x}}', 'tr', 'index.html'), /Unrendered token/);
  assert.throws(() => assertNoTokens('hi {{{x}}}', 'tr', 'index.html'), /Unrendered token/);
});
test('assertNoTokens ignores stray braces in inline JS / code', () => {
  assert.doesNotThrow(() => assertNoTokens('if (x) { foo(); }', 'en', 'index.html'));
  assert.doesNotThrow(() => assertNoTokens('var o = {a:1};', 'en', 'index.html'));
});

// --- buildContext ---
test('buildContext merges copy + computed keys', () => {
  const ctx = buildContext({ lang: 'tr', copy: { 'nav.how': 'Nasil' }, flags: { tr: '<svg id="tr"/>', en: '<svg id="en"/>' } });
  assert.equal(ctx.lang, 'tr');
  assert.equal(ctx.code, 'TR');
  assert.equal(ctx['nav.how'], 'Nasil');
  assert.equal(ctx['flag.current'], '<svg id="tr"/>');
  assert.equal(ctx['flag.en'], '<svg id="en"/>');
});
test('buildContext loads Noto only for hi/zh', () => {
  const f = { hi: '<svg/>', zh: '<svg/>', en: '<svg/>' };
  assert.match(buildContext({ lang: 'hi', copy: {}, flags: f })['fonts_noto'], /Noto\+Sans\+Devanagari/);
  assert.match(buildContext({ lang: 'zh', copy: {}, flags: f })['fonts_noto'], /Noto\+Sans\+SC/);
  assert.equal(buildContext({ lang: 'en', copy: {}, flags: f })['fonts_noto'], '');
});

// --- buildAll (integration) ---
test('buildAll renders EN to root + others to subdirs; inlines detect (rendered), flags (decorative), lang-menu', () => {
  const tmp = mkdtempSync(join(tmpdir(), 'build-site-'));
  try {
    const src = join(tmp, 'src'), out = join(tmp, 'out');
    mkdirSync(join(src, 'i18n'), { recursive: true });
    mkdirSync(join(src, 'flags'), { recursive: true });
    const pageBody = '<body>{{{flag.current}}} {{code}} {{nav.how}} {{{flag.de}}} <script>/*LANGMENU*/</script></body>';
    writeFileSync(join(src, 'index.html'), `<html lang="{{lang}}"><head><script>/*DETECT*/</script></head>${pageBody}`);
    writeFileSync(join(src, 'docs.html'), `<html lang="{{lang}}"><head><script>/*DETECT*/</script></head>${pageBody}`);
    writeFileSync(join(src, 'i18n', 'en.json'), JSON.stringify({ 'nav.how': 'How it works' }));
    writeFileSync(join(src, 'i18n', 'tr.json'), JSON.stringify({ 'nav.how': 'Nasil' }));
    writeFileSync(join(src, 'detect.js'), 'console.log("detect"); var s = {{{supported_list}}}; var b = \'{{base}}\';');
    writeFileSync(join(src, 'lang-menu.js'), 'console.log("lang-menu");');
    // realistic flags: XML prolog + role/aria-label that the build must strip
    for (const l of SUPPORTED) {
      writeFileSync(join(src, 'flags', `${l}.svg`), `<?xml version="1.0"?><svg role="img" aria-label="${l}" id="${l}"/>`);
    }

    const written = buildAll({ srcDir: src, outDir: out, langs: ['en', 'tr'] });

    assert.deepEqual(
      written.sort(),
      [join(out, 'index.html'), join(out, 'docs.html'), join(out, 'tr', 'index.html'), join(out, 'tr', 'docs.html')].sort()
    );
    const enIdx = readFileSync(join(out, 'index.html'), 'utf8');
    const trDocs = readFileSync(join(out, 'tr', 'docs.html'), 'utf8');

    assert.match(enIdx, /lang="en"/);
    assert.match(trDocs, /lang="tr"/);
    // copy
    assert.ok(enIdx.includes('How it works'));
    assert.ok(trDocs.includes('Nasil'));
    // detect inlined AND rendered through the engine (tokens resolved)
    assert.ok(enIdx.includes('console.log("detect");'));
    assert.ok(enIdx.includes('["en","tr","zh","hi","de","fr","nl"]'));
    assert.ok(enIdx.includes("var b = '/review-pro';"));
    assert.ok(!enIdx.includes('{{{supported_list}}}'));
    assert.ok(!enIdx.includes('{{base}}'));
    // lang-menu inlined via /*LANGMENU*/
    assert.ok(enIdx.includes('console.log("lang-menu");'));
    // flags: decorative + prolog/role/aria-label stripped
    assert.ok(enIdx.includes('aria-hidden="true"'));
    assert.ok(enIdx.includes('focusable="false"'));
    assert.ok(enIdx.includes('id="en"'));
    assert.ok(!enIdx.includes('<?xml'));
    assert.ok(!enIdx.includes('role="img"'));
    assert.ok(!enIdx.includes('aria-label="en"'));
    // all flags load even when only en/tr are built
    assert.ok(enIdx.includes('id="de"'));
    // no leftover tokens (scoped check)
    assert.ok(!/\{\{\{?\s*[\w.-]+\s*\}?\}\}/.test(enIdx));
    assert.ok(!/\{\{\{?\s*[\w.-]+\s*\}?\}\}/.test(trDocs));
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});

test('buildAll throws on parity failure (missing key in a translation)', () => {
  const tmp = mkdtempSync(join(tmpdir(), 'build-site-parity-'));
  try {
    const src = join(tmp, 'src'), out = join(tmp, 'out');
    mkdirSync(join(src, 'i18n'), { recursive: true });
    writeFileSync(join(src, 'index.html'), '<html lang="{{lang}}">{{nav.how}}</html>');
    writeFileSync(join(src, 'i18n', 'en.json'), JSON.stringify({ 'nav.how': 'How it works' }));
    writeFileSync(join(src, 'i18n', 'tr.json'), JSON.stringify({})); // missing nav.how
    assert.throws(() => buildAll({ srcDir: src, outDir: out, langs: ['en', 'tr'] }), /parity error.*tr.*nav\.how/i);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});

test("buildAll throws if 'en' is not in langs", () => {
  assert.throws(() => buildAll({ srcDir: '.', outDir: '.', langs: ['tr'] }), /'en' must be included/);
});
