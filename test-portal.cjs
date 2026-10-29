const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');

async function openDashboard(role) {
  const els = new Map();
  const el = id => {
    if (!els.has(id)) els.set(id, { hidden: true, textContent: '', innerHTML: '', value: '', reset() {} });
    return els.get(id);
  };
  const reply = data => ({ ok: true, json: async () => data });
  const fetch = async url => {
    if (url === '/api/config') return reply({ supabaseUrl: 'https://example.test', supabaseAnonKey: 'public' });
    if (url.includes('/auth/v1/token')) return reply({ access_token: 'token', user: { id: 'user-1' } });
    if (url.includes('trustlane_profiles?user_id=')) return reply([{ display_name: 'Test User', role, active: true }]);
    if (url.includes('trustlane_quote_requests')) return reply([{ id: 'lead-1', name: 'Test Lead', pickup: 'A', delivery: 'B', vehicle_make: 'Make', vehicle_model: 'Model', status: 'New', created_at: '2026-01-01' }]);
    if (url.includes('trustlane_notes')) return reply([]);
    if (url.includes('trustlane_tasks')) return reply([{ id: 'task-1', lead_id: 'lead-1', title: '<Call customer>', due_on: '2026-11-01', completed: false }]);
    if (url.includes('trustlane_profiles?role=eq.agent')) return reply([{ user_id: 'agent-1', display_name: '<Agent>', active: true }]);
    throw new Error('Unexpected endpoint: ' + url);
  };
  const context = { document: { querySelector: s => el(s) }, fetch, FormData: class { *[Symbol.iterator]() { yield ['email', 'test@example.test']; yield ['password', 'test']; } }, URLSearchParams, location: { hash: '', pathname: '/portal.html' }, history: { replaceState() {} }, Date, console };
  vm.runInNewContext(fs.readFileSync('portal.js', 'utf8'), context);
  await new Promise(resolve => setImmediate(resolve));
  await el('#login-form').onsubmit({ preventDefault(){}, target: { reset(){} } });
  return el;
}

test('administrator sees team management and lead summary with escaped agent names', async () => {
  const el = await openDashboard('admin');
  assert.equal(el('#dashboard').hidden, false);
  assert.equal(el('#agent-management').hidden, false);
  assert.equal(el('#stat-total').textContent, 1);
  assert.equal(el('#stat-new').textContent, 1);
  assert.match(el('#agent-list').innerHTML, /&lt;Agent&gt;/);
});

test('agent does not see administrator team management', async () => {
  const el = await openDashboard('agent');
  assert.equal(el('#dashboard').hidden, false);
  assert.equal(el('#agent-management').hidden, true);
  assert.equal(el('#stat-total').textContent, 1);
});

test('open follow-ups show the customer and safely open the lead', async () => {
  const el = await openDashboard('agent');
  assert.equal(el('#overview-count').textContent, '1 open');
  assert.match(el('#task-overview').innerHTML, /&lt;Call customer&gt;/);
  assert.match(el('#task-overview').innerHTML, /Test Lead/);
  el('#task-overview').onclick({ target: { closest: () => ({ dataset: { lead: 'lead-1' } }) } });
  await new Promise(resolve => setImmediate(resolve));
  assert.match(el('#detail').innerHTML, /Test Lead/);
});

test('lead detail renders escaped follow-up tasks', async () => {
  const el = await openDashboard('agent');
  el('#leads').onclick({ target: { closest: () => ({ dataset: { id: 'lead-1' } }) } });
  await new Promise(resolve => setImmediate(resolve));
  assert.match(el('#task-list').innerHTML, /&lt;Call customer&gt;/);
  assert.match(el('#task-list').innerHTML, /Complete/);
  assert.equal(typeof el('#task-form').onsubmit, 'function');
});

