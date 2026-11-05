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
