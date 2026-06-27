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

test('renderTemplate throws on prototype-inherited keys', () => {
  assert.throws(() => renderTemplate('{{toString}}', {}), /Missing i18n key: toString/);
});

test('renderTemplate supports dotted keys and whitespace tolerance', () => {
  assert.equal(renderTemplate('{{ nav.how }}', { 'nav.how': 'How it works' }), 'How it works');
});
