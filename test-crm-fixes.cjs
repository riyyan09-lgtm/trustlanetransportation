const test=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs');
const code=fs.readFileSync('portal.js','utf8');
function extract(start,end){const a=code.indexOf(start),b=code.indexOf(end,a);if(a<0||b<0)throw Error('missing function');return code.slice(a,b)}
test('loads all lead pages in stable order',async()=>{
 const calls=[];const ctx={api:async path=>{calls.push(path);return calls.length===1?Array.from({length:1000},(_,id)=>({id})): [{id:1000}];}};
 vm.createContext(ctx);vm.runInContext(extract('async function fetchAll(', 'async function load()'),ctx);
 const leads=await ctx.fetchAll('/rest/v1/leads?order=created_at.desc,id.desc');
 assert.equal(leads.length,1001);assert.match(calls[1],/offset=1000/);
});
test('a non-remembered sign-in clears any older remembered account',()=>{
 const removed=[];const ctx={token:null,user:null,refreshSecret:null,rememberSession:false,refreshTimer:null,localStorage:{setItem(){throw Error('should not save')},removeItem(k){removed.push(k)}},setTimeout(){return 1},clearTimeout(){},refreshSession(){}};
 vm.createContext(ctx);vm.runInContext(extract('function acceptSession(', 'async function refreshSession()'),ctx);
 ctx.acceptSession({access_token:'new',refresh_token:'refresh',user:{id:'new'},expires_in:3600},false);
 assert.deepEqual(removed,['trustlane-session']);assert.equal(ctx.token,'new');
});

