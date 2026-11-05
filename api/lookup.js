const cache = new Map();
module.exports = async function handler(req,res){
  res.setHeader('X-Robots-Tag','noindex');
  const {kind,zip,make,year}=req.query;
  let url;
  if(kind==='zip' && /^\d{5}$/.test(zip||'')) url='https://api.zippopotam.us/us/'+zip;
  else if(kind==='makes') url='https://vpic.nhtsa.dot.gov/api/vehicles/GetAllMakes?format=json';
  else if(kind==='models' && typeof make==='string' && make.trim().length>0 && make.length<=80 && /^\d{4}$/.test(year||'') && +year>=1886 && +year<=2100) url='https://vpic.nhtsa.dot.gov/api/vehicles/GetModelsForMakeYear/make/'+encodeURIComponent(make.trim())+'/modelyear/'+year+'?format=json';
  else return res.status(400).json({error:'Invalid lookup parameters.'});
  const cached=cache.get(url);if(cached&&cached.expires>Date.now())return res.status(200).json(cached.data);
  try{
    const response=await fetch(url,{signal:AbortSignal.timeout(8000)});
    if(response.status===404&&kind==='zip')return res.status(404).json({error:'No location found for this ZIP.'});
    if(!response.ok)throw Error('Lookup unavailable');
    const raw=await response.json();let data;
    if(kind==='zip') data={places:[...new Set((raw.places||[]).map(p=>[p['place name'],p['state abbreviation']].filter(Boolean).join(', ')).filter(Boolean))]};
    else data={values:[...new Set((raw.Results||[]).map(x=>String((kind==='makes'?x.Make_Name:x.Model_Name)||'').trim()).filter(Boolean))].sort((a,b)=>a.localeCompare(b))};
    cache.set(url,{data,expires:Date.now()+3600000});if(cache.size>300)cache.delete(cache.keys().next().value);
    res.setHeader('Cache-Control','public, max-age=3600');return res.status(200).json(data);
  }catch{return res.status(503).json({error:'Lookup unavailable. Please try again or enter details manually.'});}
};
