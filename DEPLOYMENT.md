# Trustlane deployment notes (work in progress)

This project is not ready for production. Database migrations were applied through Supabase MCP on 2026-10-28; legacy tables have RLS enabled with no policies, and access to the two legacy views was revoked. Existing clients using anon/authenticated keys against these resources will stop working. Existing service-role workflows were not inspected or verified.

The new CRM uses a separate set of tables. No existing records were imported. All legacy tables reported zero rows when inspected; recheck before assuming that remains true. The site and portal require further testing, security review, configuration and deployment. There is no verified pricing or booking integration.

Vercel server environment variables: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY, TURNSTILE_SITE_KEY, TURNSTILE_SECRET_KEY and SITE_URL. Never put the service-role or Turnstile secret in browser code or source control. Rotate the previously shared service-role key before configuring it. The quote endpoint fails closed without its configuration. Configure Supabase Auth site URL and redirect allowlist for /portal.html and verify invitation email delivery. Turnstile must be configured for the deployed domain. Signups should be disabled if invitations are the intended provisioning path.

For bootstrap, create an administrator through Supabase Auth, then insert a matching UUID into public.trustlane_profiles with role admin and active true through a trusted SQL editor. Do not grant this role to an unverified user. The portal includes agent invitation and activation controls, but the complete flow has not been tested.

The website draft has not been checked against all mobile widths and the portal has not been browser tested. Neither is deployed from this workspace. RLS was verified using temporary test identities in a rolled-back transaction; this is not a substitute for testing actual sign-in and browser/API behavior.

