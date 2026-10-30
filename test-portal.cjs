const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');

async function openDashboard(role, existingOrder=false) {
  const els = new Map();
  const el = id => {
    if (!els.has(id)) els.set(id, { hidden: true, textContent: '', innerHTML: '', value: '', reset() {},classList:{add(){},remove(){}} });
    return els.get(id);
  };
  const reply = data => ({ ok: true, json: async () => data });
  const panels=['overview','shipment','vehicles','quotes','order','activity','payment','contact','tasks','notes'].map(name=>({dataset:{detailPanel:name},hidden:false}));
  const tabs=panels.map(p=>({dataset:{detailTab:p.dataset.detailPanel},setAttribute(k,v){this[k]=v}}));
  const requests = [];
  const fetch = async (url, options) => {
    requests.push({url, options});
    if (url === '/api/config') return reply({ supabaseUrl: 'https://example.test', supabaseAnonKey: 'public' });
    if (url.includes('/auth/v1/token')) return reply({ access_token: 'token', user: { id: 'user-1' } });
    if (url.includes('trustlane_profiles?user_id=')) return reply([{ display_name: 'Test User', role, active: true }]);
    if (url.includes('trustlane_quote_requests')) return reply([{ id: 'lead-1', name: 'Test Lead', email:'test@example.test', pickup: 'A', delivery: 'B', vehicle_make: 'Make', vehicle_model: 'Model', status: 'New', created_at: '2026-01-01' }]);
    if (url.includes('trustlane_notes')) return reply([]);
    if (url.includes('trustlane_lead_activity')) return reply([{ occurred_at: '2026-10-30T12:00:00Z', changes: { working_status: { from: 'New', to: '<Follow Up>' } } }]);
    if (url.includes('trustlane_quote_drafts')) return reply([{ id: 'quote-1', created_at: '2026-10-30T12:00:00Z', snapshot: { name:'Test Lead', pickup:'A', delivery:'B', quote_amount: 123.45, special_terms:'<terms>', additional_vehicles:[{year:2021,make:'Test',model:'Second'}] } }]);
    if (url.includes('trustlane_order_events')) return reply([{created_at:'2026-10-30T12:00:00Z',previous_stage:'Dispatched',new_stage:'<Picked up>'}]);
    if (url.includes('trustlane_orders')) return reply(existingOrder?[{id:'order-1',stage:'Dispatched',created_at:'2026-10-30T12:00:00Z',confirmation_note:'<Agreed>'}]:[]);
    if (url.includes('rpc/trustlane_record_manual_order')) return reply('order-1');
    if (url.includes('trustlane_vehicles')) return reply([{id:'vehicle-1',year:2021,make:'Test',model:'<Second>',active:true}]);
    if (url.includes('trustlane_contact_events')) return reply([{kind:'Call',outcome:'<No answer>',details:'Follow up',created_at:'2026-10-30T12:00:00Z'}]);
    if (url.includes('trustlane_payment_records')) return reply([{kind:'Payment',amount:125,transaction_date:'2026-10-30',reference:'<ref>'}]);
    if (url.includes('trustlane_tasks')) return reply([{ id: 'task-1', lead_id: 'lead-1', title: '<Call customer>', due_on: '2026-11-01', completed: false }]);
    if (url.includes('trustlane_profiles?role=eq.agent')) return reply([{ user_id: 'agent-1', display_name: '<Agent>', active: true }]);
    throw new Error('Unexpected endpoint: ' + url);
  };
  let downloaded = '';
  const context = { document: { querySelector: s => el(s),querySelectorAll: s => s.includes('data-detail-panel')?panels:tabs, createElement: () => ({ click() {} }) }, fetch, FormData: class { constructor(form){this.values=form.values||{email:'test@example.test',password:'test'}} get(k){return this.values[k]??null} *[Symbol.iterator]() { yield* Object.entries(this.values); } }, URLSearchParams, location: { hash: '', pathname: '/portal.html' }, history: { replaceState() {} }, Date, console, Blob: class { constructor(parts) { downloaded = parts.join(''); } }, URL: { createObjectURL: () => 'blob:test', revokeObjectURL() {} }, setTimeout: fn => fn() };
  vm.runInNewContext(fs.readFileSync('portal.js', 'utf8'), context);
  await new Promise(resolve => setImmediate(resolve));
  await el('#login-form').onsubmit({ preventDefault(){}, target: { reset(){} } });
  el.downloaded = () => downloaded;
  el.requests = requests;
  el.panels = panels; el.tabs = tabs;
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

test('manual order submits selected quote and explicit confirmation', async () => {
  const el = await openDashboard('agent');
  el('#leads').onclick({ target: { closest: () => ({ dataset: { id: 'lead-1' } }) } });
  await new Promise(resolve => setImmediate(resolve));
  const button={disabled:false};
  await el('#order-create-form').onsubmit({preventDefault(){},target:{querySelector:()=>button,values:{quote_id:'quote-1',confirmation_note:'Customer agreed by phone',confirmed:'on'}}});
  const request=el.requests.find(r=>r.url.includes('rpc/trustlane_record_manual_order'));
  assert.deepEqual(JSON.parse(request.options.body),{p_lead_id:'lead-1',p_quote_id:'quote-1',p_confirmation_note:'Customer agreed by phone',p_confirmed:true});
  assert.equal(button.disabled,false);
});

test('order view shows escaped agreement and stage history', async () => {
  const el = await openDashboard('agent',true);
  el('#leads').onclick({target:{closest:()=>({dataset:{id:'lead-1'}})}});
  await new Promise(resolve=>setImmediate(resolve));
  assert.match(el('#order-content').innerHTML,/&lt;Agreed&gt;/);
  assert.match(el('#order-history').innerHTML,/&lt;Picked up&gt;/);
  assert.equal(typeof el('#order-stage-form').onsubmit,'function');
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
  assert.match(el('#detail').innerHTML, /data-detail-tab="vehicles"/);
  assert.match(el('#detail').innerHTML, /data-detail-panel="order"/);
});

test('lead detail renders escaped follow-up tasks', async () => {
  const el = await openDashboard('agent');
  el('#leads').onclick({ target: { closest: () => ({ dataset: { id: 'lead-1' } }) } });
  await new Promise(resolve => setImmediate(resolve));
  assert.match(el('#task-list').innerHTML, /&lt;Call customer&gt;/);
  assert.match(el('#task-list').innerHTML, /Complete/);
  assert.equal(typeof el('#task-form').onsubmit, 'function');
  assert.match(el('#working-details').innerHTML, /Customer quote amount/);
  assert.match(el('#working-details').innerHTML, /Carrier pay/);
  assert.match(el('#working-details').innerHTML, /Working status/);
  assert.equal(typeof el('#working-form').onsubmit, 'function');
  assert.match(el('#vehicle-list').innerHTML, /&lt;Second&gt;/);
  assert.equal(typeof el('#vehicle-add').onsubmit, 'function');
  assert.match(el('#contact-list').innerHTML, /&lt;No answer&gt;/);
  assert.equal(typeof el('#contact-form').onsubmit, 'function');
  assert.match(el('#payment-list').innerHTML, /&lt;ref&gt;/);
  assert.equal(typeof el('#payment-form').onsubmit, 'function');
  assert.match(el('#activity-list').innerHTML, /&lt;Follow Up&gt;/);
  assert.match(el('#quote-list').innerHTML, /123\.45/);
  assert.match(el('#quote-list').innerHTML, /mailto:test%40example.test/);
  assert.match(el('#quote-list').innerHTML, /%3Cterms%3E/);
  assert.equal(typeof el('#quote-form').onsubmit, 'function');
  assert.match(el('#order-content').innerHTML, /confirmed the customer agreed/);
  assert.equal(typeof el('#order-create-form').onsubmit, 'function');
  el('#quote-list').onclick({target:{closest:()=>({dataset:{quote:'quote-1'}})}});
  assert.match(el.downloaded(), /&lt;terms&gt;/);
  assert.match(el.downloaded(), /2021 Test Second/);
  assert.doesNotMatch(el.downloaded(), /Carrier pay/);
});

test('pipeline view filters leads by stage', async () => {
  const el = await openDashboard('agent');
  el('#pipeline').value = 'quotes'; el('#pipeline').onchange();
  assert.equal(el('#lead-count').textContent, '0 shown');
  el('#pipeline').value = 'leads'; el('#pipeline').onchange();
  assert.equal(el('#lead-count').textContent, '1 shown');
  assert.equal(el('#inbox-title').textContent, 'Leads');
  assert.match(el('#pipeline-nav').innerHTML, /Quotes/);
  el('#pipeline-nav').onclick({target:{closest:()=>({dataset:{view:'orders'}})}});
  assert.equal(el('#inbox-title').textContent, 'Orders');
  assert.equal(el('#lead-count').textContent, '0 shown');
});

test('lead workspace switches between panels without hiding the selected panel', async () => {
  const el=await openDashboard('agent');
  el('#leads').onclick({target:{closest:()=>({dataset:{id:'lead-1'}})}});
  await new Promise(resolve=>setImmediate(resolve));
  assert.equal(el.panels.find(p=>p.dataset.detailPanel==='overview').hidden,false);
  el('#detail').onclick({target:{closest:s=>s==='#detail-close'?null:{dataset:{detailTab:'vehicles'}}}});
  assert.equal(el.panels.find(p=>p.dataset.detailPanel==='vehicles').hidden,false);
  assert.equal(el.panels.find(p=>p.dataset.detailPanel==='overview').hidden,true);
  assert.equal(el.tabs.find(t=>t.dataset.detailTab==='vehicles')['aria-pressed'],'true');
});

test('filters work by email and route', async () => {
  const el = await openDashboard('agent');
  el('#search').value='test@example.test'; el('#search').oninput();
  assert.equal(el('#lead-count').textContent,'1 shown');
  el('#pickup-filter').value='other'; el('#pickup-filter').oninput();
  assert.equal(el('#lead-count').textContent,'0 shown');
});

test('manual lead entry is available to an agent', async () => {
  const el = await openDashboard('agent');
  assert.equal(typeof el('#manual-lead-form').onsubmit, 'function');
  assert.match(fs.readFileSync('portal.html', 'utf8'), /name="vehicle_year"/);
});
