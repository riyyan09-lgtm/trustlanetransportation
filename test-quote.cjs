const test=require('node:test');const assert=require('node:assert/strict');const handler=require('./api/quote');
function res(){return {statusCode:200,headers:{},setHeader(k,v){this.headers[k]=v},status(n){this.statusCode=n;return this},json(v){this.body=v;return this}}}
const valid={request_id:'a17f99d3-11a7-46d8-b283-fc79a23b7bc1',name:'Test Customer',email:'test@example.test',phone:'5555551234',pickup:'Austin TX',delivery:'Dallas TX',vehicle_year:2020,vehicle_make:'Ford',vehicle_model:'Focus',preferred_date:'2027-01-01',details:'',turnstile_token:'token'};
test('rejects invalid inputs',async()=>{const r=res();await handler({method:'POST',headers:{},body:{...valid,email:'bad'}},r);assert.equal(r.statusCode,400)});
test('fails closed when configuration is missing',async()=>{const r=res();await handler({method:'POST',headers:{},body:valid},r);assert.equal(r.statusCode,503)});
test('returns success only after verification and persistence',async()=>{process.env.SUPABASE_URL='https://esevschvewgsvrisyixd.supabase.co';process.env.SUPABASE_SERVICE_ROLE_KEY='fake';process.env.TURNSTILE_SECRET_KEY='fake';let calls=0;global.fetch=async()=>{calls++;return calls===1?{ok:true,json:async()=>({success:true})}:{ok:true}};const r=res();await handler({method:'POST',headers:{},body:valid},r);assert.equal(r.statusCode,200);assert.equal(calls,2)});
test('reports failure when persistence fails',async()=>{let calls=0;global.fetch=async()=>{calls++;return calls===1?{ok:true,json:async()=>({success:true})}:{ok:false}};const r=res();await handler({method:'POST',headers:{},body:valid},r);assert.equal(r.statusCode,503)});


