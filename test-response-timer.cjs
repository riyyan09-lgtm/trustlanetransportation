const test=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs');
const source=fs.readFileSync('portal.js','utf8');
const start=source.indexOf('function responseText('),end=source.indexOf('function updateResponse(',start);
const context={Date};vm.createContext(context);vm.runInContext(source.slice(start,end),context);
test('response timer counts from actual arrival and marks overdue',()=>{
 const lead={created_at:'2026-11-05T12:00:00Z'},arrival=Date.parse(lead.created_at);
 assert.match(context.responseText(lead,[],arrival+10000).text,/20s remaining/);
 assert.equal(context.responseText(lead,[],arrival+31000).overdue,true);
 assert.match(context.responseText(lead,[],arrival+31000).text,/overdue by 0:01/);
});
test('first recorded contact stops the timer using the event time',()=>{
 const lead={created_at:'2026-11-05T12:00:00Z'},arrival=Date.parse(lead.created_at);
 const state=context.responseText(lead,[{kind:'Text',created_at:'2026-11-05T12:00:12Z'}],arrival+60000);
 assert.equal(state.text,'First attempt logged in 0:12');assert.equal(state.overdue,false);
});
test('missing arrival never invents a timer',()=>assert.match(context.responseText({},[],0).text,/unavailable/));
test('voicemail counts as a logged call attempt and older overdue times stay readable',()=>{
 const lead={created_at:'2026-11-05T12:00:00Z'},arrival=Date.parse(lead.created_at);
 assert.equal(context.responseText(lead,[{kind:'Voicemail',created_at:'2026-11-05T12:00:25Z'}],arrival+60000).text,'First attempt logged in 0:25');
 assert.match(context.responseText(lead,[],arrival+90000000).text,/1d/);
});

