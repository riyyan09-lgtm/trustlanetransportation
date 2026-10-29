module.exports = function handler(req,res){
 res.setHeader('Cache-Control','no-store');res.setHeader('X-Robots-Tag','noindex, nofollow');
 const expected='https://esevschvewgsvrisyixd.supabase.co';
 const configured=process.env.SUPABASE_URL || '';
 // This is the project's public, browser-safe Supabase key, not a service-role key.
 const publicKey=process.env.SUPABASE_PUBLISHABLE_KEY || 'sb_publishable_x6MHLmvM9goxrQVGfWPsoA_-zz96zxb';
 return res.status(200).json({supabaseUrl:configured===expected?expected:'',supabaseAnonKey:configured===expected?publicKey:''});
};

