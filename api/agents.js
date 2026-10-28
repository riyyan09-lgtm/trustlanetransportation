module.exports=async function handler(req,res){
 res.setHeader('Cache-Control','no-store');if(req.method!=='POST')return res.status(405).json({error:'Method not allowed.'});
 const {SUPABASE_URL,SUPABASE_SERVICE_ROLE_KEY}=process.env; const SUPABASE_ANON_KEY=process.env.SUPABASE_ANON_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;const token=(req.headers.authorization||'').replace(/^Bearer\s+/i,'');
 if(SUPABASE_URL !== 'https://esevschvewgsvrisyixd.supabase.co'||!SUPABASE_SERVICE_ROLE_KEY||!SUPABASE_ANON_KEY)return res.status(503).json({error:'Portal configuration is incomplete.'});
 if(!token)return res.status(401).json({error:'Sign in required.'});
 try{
  const userRes=await fetch(`${SUPABASE_URL}/auth/v1/user`,{headers:{apikey:SUPABASE_ANON_KEY,Authorization:`Bearer ${token}`}});if(!userRes.ok)return res.status(401).json({error:'Session expired.'});const user=await userRes.json();
  const profiles=await fetch(`${SUPABASE_URL}/rest/v1/trustlane_profiles?user_id=eq.${encodeURIComponent(user.id)}&select=role,active`,{headers:{apikey:SUPABASE_ANON_KEY,Authorization:`Bearer ${token}`}});const rows=await profiles.json();if(!profiles.ok||!Array.isArray(rows)||!rows[0]?.active||rows[0]?.role!=='admin')return res.status(403).json({error:'Administrator access required.'});
  const b=req.body||{};
  if(b.action==='deactivate'||b.action==='reactivate'){
   if(!/^[0-9a-f-]{36}$/i.test(b.user_id||'')||b.user_id===user.id)return res.status(400).json({error:'Invalid agent.'});
   const update=await fetch(`${SUPABASE_URL}/rest/v1/trustlane_profiles?user_id=eq.${encodeURIComponent(b.user_id)}&role=eq.agent`,{method:'PATCH',headers:{apikey:SUPABASE_SERVICE_ROLE_KEY,Authorization:`Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,'Content-Type':'application/json',Prefer:'return=representation'},body:JSON.stringify({active:b.action==='reactivate'})});const data=await update.json();if(!update.ok||!Array.isArray(data)||data.length!==1)throw Error('update failed');return res.status(200).json({success:true});
  }
  if(b.action!=='invite'||typeof b.email!=='string'||b.email.length>254||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(b.email)||typeof b.name!=='string'||b.name.trim().length<1||b.name.length>120)return res.status(400).json({error:'Enter a valid name and email.'});
  const redirect=process.env.SITE_URL ? `?redirect_to=${encodeURIComponent(process.env.SITE_URL.replace(/\/$/,'')+'/portal.html')}` : '';
  const invite=await fetch(`${SUPABASE_URL}/auth/v1/invite${redirect}`, {method:'POST',headers:{apikey:SUPABASE_SERVICE_ROLE_KEY,Authorization:`Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,'Content-Type':'application/json'},body:JSON.stringify({email:b.email.trim()})});const invited=await invite.json();if(!invite.ok||!invited.id) return res.status(400).json({error:'The invitation could not be created. Check the email and Supabase Auth settings.'});
  const created=await fetch(`${SUPABASE_URL}/rest/v1/trustlane_profiles`,{method:'POST',headers:{apikey:SUPABASE_SERVICE_ROLE_KEY,Authorization:`Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,'Content-Type':'application/json',Prefer:'return=minimal'},body:JSON.stringify({user_id:invited.id,display_name:b.name.trim(),role:'agent',active:true})});
  if(!created.ok)return res.status(500).json({error:'The Auth invitation was created, but portal access was not. Ask an administrator to check the profile before retrying.'});return res.status(200).json({success:true});
 }catch{return res.status(503).json({error:'Could not complete the request. Please try again.'});}
};

