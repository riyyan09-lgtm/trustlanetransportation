const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const html = fs.readFileSync('index.html', 'utf8');
const portal = fs.readFileSync('portal.html', 'utf8');
const css = fs.readFileSync('style.css', 'utf8');

test('public navigation anchors resolve to homepage sections', () => {
  const ids = new Set([...html.matchAll(/\bid="([^"]+)"/g)].map((match) => match[1]));
  const missing = [...html.matchAll(/href="#([^"]+)"/g)]
    .map((match) => match[1])
    .filter((id) => !ids.has(id));
  assert.deepEqual(missing, []);
});

test('quote form requests contact, route, vehicle, and date details', () => {
  for (const field of ['name', 'email', 'phone', 'pickup', 'delivery', 'vehicle_year', 'vehicle_make', 'vehicle_model', 'preferred_date']) {
    assert.match(html, new RegExp(`name="${field}"[^>]*required`));
  }
  assert.match(html, /id="quote-result"[^>]*aria-live="polite"/);
});

test('portal is excluded from indexing and responsive breakpoints exist', () => {
  assert.match(portal, /<meta name="robots" content="noindex,nofollow">/);
  assert.match(css, /@media\s*\(max-width:\s*1000px\)/);
  assert.match(css, /@media\s*\(max-width:\s*700px\)/);
  assert.match(css, /@media\s*\(max-width:\s*420px\)/);
  assert.match(css, /prefers-reduced-motion:\s*reduce/);
});
