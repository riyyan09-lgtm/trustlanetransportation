module.exports = function handler(req,res){
 res.setHeader('Cache-Control','no-store');
 const expected='https://esevschvewgsvrisyixd.supabase.co';
 const configured=process.env.SUPABASE_URL || '';
 return res.status(200).json({turnstileSiteKey:process.env.TURNSTILE_SITE_KEY || '',supabaseUrl:configured===expected?expected:'',supabaseAnonKey:configured===expected?(process.env.SUPABASE_ANON_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || ''):''});
};

