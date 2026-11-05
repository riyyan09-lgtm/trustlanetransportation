const test=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs');
const source=fs.readFileSync('portal.js','utf8');
const start=source.indexOf('function locationZip('),end=source.indexOf('function assignedName(',start);
const context={};vm.createContext(context);vm.runInContext(source.slice(start,end),context);
test('ZIP extraction requires one unambiguous trailing ZIP',()=>{
 assert.equal(context.locationZip('Dallas, TX 75201'),'75201');
 assert.equal(context.locationZip('75201-1234'),'75201-1234');
 assert.equal(context.locationZip('Dallas, TX'),'');
 assert.equal(context.locationZip('12345 Main Street, Dallas TX 75201'),'');
 assert.equal(context.locationZip('12345 Main Street'),'');
});
test('vehicle copy requires year, make and model',()=>{
 assert.equal(context.completeVehicle({vehicle_year:2020,vehicle_make:'Toyota',vehicle_model:'Camry'}),'2020 Toyota Camry');
 assert.equal(context.completeVehicle({vehicle_year:2020,vehicle_make:'Toyota'}),'');
});
test('ZIP button copies the actual ZIP and reports failure',async()=>{
 let copied='';const buttons=['pickup','delivery'].map(field=>({dataset:{copyField:field},innerHTML:'ZIP',isConnected:true}));
 const ctx={navigator:{clipboard:{writeText:async value=>{copied=value}}},msg:{textContent:''},setTimeout:()=>{},document:{querySelectorAll:()=>buttons}};
 vm.createContext(ctx);vm.runInContext(source.slice(start,source.indexOf('async function saveQuickPrice(',start)),ctx);
 ctx.bindCopyButtons({pickup:'Dallas TX 75201',delivery:'85001-1234'});await buttons[0].onclick();assert.equal(copied,'75201');assert.match(buttons[0].textContent,/Copied/);await buttons[1].onclick();assert.equal(copied,'85001-1234');ctx.navigator.clipboard.writeText=async()=>{throw Error()};await buttons[0].onclick();assert.match(ctx.msg.textContent,/Copy failed/);
});
