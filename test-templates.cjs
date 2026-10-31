const test=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const source=fs.readFileSync('portal.js','utf8');
const start=source.indexOf('function fillTemplate('), end=source.indexOf('async function openTemplates(',start);
const context={};vm.createContext(context);vm.runInContext(source.slice(start,end),context);
test('templates use selected lead details and do not invent a quote',()=>{
 const text=context.fillTemplate('Hi {{name}}: {{pickup}} to {{delivery}}; {{vehicle}}; {{quote}}',{name:'Test',pickup:'Dallas',delivery:'Phoenix',vehicle_year:2022,vehicle_make:'Toyota',vehicle_model:'Camry',quote_amount:null});
 assert.equal(text,'Hi Test: Dallas to Phoenix; 2022 Toyota Camry; Please ask for a quote');
});
test('template quote uses saved amount',()=>assert.equal(context.fillTemplate('{{quote}}',{quote_amount:123.5}),'$123.50'));

