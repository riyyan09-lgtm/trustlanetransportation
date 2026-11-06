const fs=require('node:fs');
const path=require('node:path');
const root=__dirname;
const output=path.join(root,'dist');
const scripts=['booking.js','lead-drop.js','portal.js','script.js','vehicle-lookup.js','vehicle-makes.js'];
const files=[...fs.readdirSync(root).filter(name=>name.endsWith('.html')), ...scripts, 'style.css','robots.txt','sitemap.xml'];
for(const file of files){if(!fs.statSync(path.join(root,file)).isFile())throw Error('Missing public asset: '+file)}
fs.mkdirSync(output,{recursive:true});
for(const file of files)fs.copyFileSync(path.join(root,file),path.join(output,file));
if(fs.existsSync(path.join(root,'assets')))fs.cpSync(path.join(root,'assets'),path.join(output,'assets'),{recursive:true});
console.log('Packaged public site and portal assets. Vercel deploys api/ separately.');
