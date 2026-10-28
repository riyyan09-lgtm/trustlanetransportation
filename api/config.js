module.exports = function handler(req,res){
 res.setHeader('Cache-Control','no-store');res.setHeader('X-Robots-Tag','noindex, nofollow');
 const expected='https://esevschvewgsvrisyixd.supabase.co';
 const configured=process.env.SUPABASE_URL || '';
 return res.status(200).json({supabaseUrl:configured===expected?expected:'',supabaseAnonKey:configured===expected?(process.env.SUPABASE_ANON_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || ''):''});
};
