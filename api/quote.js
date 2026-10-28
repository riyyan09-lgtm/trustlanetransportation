const MAX_BODY = 12000;
const text = (v, min, max) => typeof v === 'string' && v.trim().length >= min && v.trim().length <= max;
module.exports = async function handler(req, res) {
  res.setHeader('Cache-Control','no-store');res.setHeader('X-Robots-Tag','noindex, nofollow');
  if(req.method !== 'POST') return res.status(405).json({error:'Method not allowed.'});
  if(Number(req.headers['content-length'] || 0) > MAX_BODY) return res.status(413).json({error:'Request too large.'});
  const b=req.body;
  if(!b || typeof b !== 'object' || JSON.stringify(b).length > MAX_BODY) return res.status(400).json({error:'Invalid request.'});
  const year=Number(b.vehicle_year);
  if(!/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(b.request_id || '') ||
     !text(b.name,2,120) || !text(b.email,5,254) || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(b.email) ||
     !text(b.phone,7,40) || (b.phone.match(/\d/g)||[]).length < 7 || !text(b.pickup,2,160) || !text(b.delivery,2,160) ||
     !Number.isInteger(year) || year<1886 || year>2100 || !text(b.vehicle_make,1,80) || !text(b.vehicle_model,1,80) ||
     !/^\d{4}-\d{2}-\d{2}$/.test(b.preferred_date || '') || Number.isNaN(Date.parse(b.preferred_date)) || new Date(b.preferred_date).toISOString().slice(0,10) !== b.preferred_date ||
     (b.details && !text(b.details,1,2000))) return res.status(400).json({error:'Please check the required fields and try again.'});
  if(b.website) return res.status(400).json({error:'Unable to submit request.'});
  const {SUPABASE_URL,SUPABASE_SERVICE_ROLE_KEY}=process.env;
  if(SUPABASE_URL !== 'https://esevschvewgsvrisyixd.supabase.co' || !SUPABASE_SERVICE_ROLE_KEY) return res.status(503).json({error:'Quote requests are temporarily unavailable. Please try again later.'});
  try {
    const ip=(req.headers['x-real-ip'] || req.headers['x-forwarded-for'] || '').toString().split(',')[0].trim().slice(0,100) || 'unknown';
    const limited=await fetch(`${SUPABASE_URL}/rest/v1/rpc/trustlane_accept_quote`,{method:'POST',headers:{apikey:SUPABASE_SERVICE_ROLE_KEY,Authorization:`Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,'Content-Type':'application/json'},body:JSON.stringify({p_key:ip})});
    if(!limited.ok) throw new Error('rate limit check failure');
    if(await limited.json() !== true) return res.status(429).json({error:'Too many requests. Please wait before trying again.'});
    const row={request_id:b.request_id,name:b.name.trim(),email:b.email.trim(),phone:b.phone.trim(),pickup:b.pickup.trim(),delivery:b.delivery.trim(),vehicle_year:year,vehicle_make:b.vehicle_make.trim(),vehicle_model:b.vehicle_model.trim(),preferred_date:b.preferred_date,details:(b.details||'').trim()};
    const saved=await fetch(`${SUPABASE_URL}/rest/v1/trustlane_quote_requests?on_conflict=request_id`,{method:'POST',headers:{apikey:SUPABASE_SERVICE_ROLE_KEY,Authorization:`Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,'Content-Type':'application/json',Prefer:'resolution=ignore-duplicates,return=minimal'},body:JSON.stringify(row)});
    if(!saved.ok) throw new Error('storage failure');
    return res.status(200).json({success:true});
  } catch {return res.status(503).json({error:'We could not save your request. Please try again.'});}
};
