const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const names=['how-it-works','services','business','shipping-costs','locations','guides','dealer-guide','prepare-vehicle'];
test('quote form is near the top and remains unique',()=>{
 const h=fs.readFileSync('index.html','utf8');assert.ok(h.indexOf('id="quote"')<h.indexOf('class="intro wrap"'));assert.equal((h.match(/id="quote-form"/g)||[]).length,1);
});
test('public pages and sitemap point to existing useful content and assets',()=>{
 const sitemap=fs.readFileSync('sitemap.xml','utf8');
 for(const name of names){const file=name+'.html',html=fs.readFileSync(file,'utf8');assert.ok(sitemap.includes('/'+file));assert.match(html,/<h1>.+<\/h1>/);assert.match(html,/href="\/#quote"/);assert.ok(fs.existsSync('assets/transport-road.jpg'));for(const m of html.matchAll(/href="(\/[^"#?]+\.html)"/g)){assert.ok(fs.existsSync(path.join('.',m[1])),'missing '+m[1]);}}
});
