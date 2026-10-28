module.exports = function handler(req,res){res.setHeader('Cache-Control','no-store');return res.status(200).json({turnstileSiteKey:process.env.TURNSTILE_SITE_KEY || '',supabaseUrl:process.env.SUPABASE_URL || '',supabaseAnonKey:process.env.SUPABASE_ANON_KEY || ''});};

