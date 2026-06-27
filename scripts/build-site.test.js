import { test } from 'node:test';
import assert from 'node:assert/strict';
import { rmSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { escapeHtml, renderTemplate, assertParity, assertNoTokens, buildContext, buildAll } from './build-site.js';

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

test('renderTemplate throws on prototype-inherited keys', () => {
  assert.throws(() => renderTemplate('{{toString}}', {}), /Missing i18n key: toString/);
});

test('renderTemplate supports dotted keys and whitespace tolerance', () => {
  assert.equal(renderTemplate('{{ nav.how }}', { 'nav.how': 'How it works' }), 'How it works');
});

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

test('buildAll renders EN to root and others to subdirs, inlines detect + flags', () => {
  const tmp = join(process.cwd(), '.tmp-build-test');
  try {
    const src = join(tmp, 'src'), out = join(tmp, 'out');
    mkdirSync(join(src, 'i18n'), { recursive: true });
    mkdirSync(join(src, 'flags'), { recursive: true });
    const pageBody = '<body>{{{flag.current}}} {{code}} {{nav.how}}</body>';
    writeFileSync(join(src, 'index.html'), `<html lang="{{lang}}"><head><script>/*DETECT*/</script></head>${pageBody}`);
    writeFileSync(join(src, 'docs.html'), `<html lang="{{lang}}"><head><script>/*DETECT*/</script></head>${pageBody}`);
    writeFileSync(join(src, 'i18n', 'en.json'), JSON.stringify({ 'nav.how': 'How it works' }));
    writeFileSync(join(src, 'i18n', 'tr.json'), JSON.stringify({ 'nav.how': 'Nasil' }));
    writeFileSync(join(src, 'detect.js'), 'console.log("detect");');
    for (const l of ['en', 'tr']) writeFileSync(join(src, 'flags', `${l}.svg`), `<svg id="${l}"/>`);

    const written = buildAll({ srcDir: src, outDir: out, langs: ['en', 'tr'] });

    assert.deepEqual(
      written.sort(),
      [join(out, 'index.html'), join(out, 'docs.html'), join(out, 'tr', 'index.html'), join(out, 'tr', 'docs.html')].sort()
    );
    const enIdx = readFileSync(join(out, 'index.html'), 'utf8');
    const trDocs = readFileSync(join(out, 'tr', 'docs.html'), 'utf8');
    assert.match(enIdx, /lang="en"/);
    assert.match(trDocs, /lang="tr"/);
    assert.ok(enIdx.includes('How it works') && enIdx.includes('<svg id="en"/>'));
    assert.ok(trDocs.includes('Nasil') && trDocs.includes('console.log("detect");'));
    assert.ok(!/\{\{/.test(enIdx) && !/\{\{/.test(trDocs));
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});
