# Trustlane deployment and operations

## Current deployment state

The Trustlane site and portal source are on the `trustlane-preview` branch of `riyyan09-lgtm/trustlanetransportation`. The Preview deployment URL is `https://trustlane-transportation-30q7rfhta-mr-development.vercel.app/`. Supabase URL, anon key, and service-role key are configured for Preview and Production using the existing values. **Preview points at the same Supabase project and data as Production. Do not submit test or sample quote requests through Preview.** Production deployment and custom-domain routing have not been changed.

The service-role key is used only by Vercel server functions. Do not place it in browser code, source control, or any `NEXT_PUBLIC_*` variable.

## Vercel environment

Required server variables:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` (or existing `NEXT_PUBLIC_SUPABASE_ANON_KEY`)
- `SUPABASE_SERVICE_ROLE_KEY`

`SITE_URL` is optional for basic password sign-in and quote submissions. Set it to the intended public domain before inviting agents so invite emails return to the correct portal URL. Supabase Auth email delivery also requires a configured SMTP provider and the portal URL in the Auth redirect allowlist.

The quote form includes a hidden honeypot, request idempotency, server validation, and a database-backed per-IP limit of five requests per hour. The database stores a one-way digest, not the raw IP address. No third-party CAPTCHA, email, SMS, or scheduling credentials are configured by this project.

## First administrator and agents

No Trustlane Auth user or portal profile exists yet for the administrator email. To create the first administrator without changing the chosen password:

1. In the correct Supabase project, create the Auth user with the administrator email and the existing chosen password. Verify the email through Supabase's user management flow.
2. Copy that user's UUID from **Authentication → Users**.
3. In the Supabase SQL editor, insert its portal profile:

```sql
insert into public.trustlane_profiles (user_id, display_name, role, active)
values ('<AUTH_USER_UUID>', '<ADMIN_DISPLAY_NAME>', 'admin', true);
```

4. Sign in at `/portal.html`. Use **Manage agents** after SMTP delivery and the portal URL redirect allowlist are configured.

Admins can assign and reassign leads, manage lead statuses, and deactivate/reactivate agent profiles. Agents only see leads assigned to their own account. Database RLS and the status RPC enforce this boundary. Do not promote a profile unless you have verified that its Auth account belongs to the intended person.

## Database and data

Migrations are in `supabase/migrations/`. They create isolated `trustlane_*` CRM tables, role-aware RLS, status management, and quote rate limiting. No legacy records were copied. At the last database check there were no Trustlane profiles or quote requests. The existing `leads`, `bookings`, and `lead_alerts` tables had no rows. Legacy RLS was enabled and anonymous/authenticated access to those tables and the `recent_leads` and `lead_alert_status` views was revoked. This can interrupt any existing browser-based integration using those objects; confirm the existing ShipGrid endpoint before switching production traffic. Service-role access is unchanged.

## Search indexing

Public search content is the homepage at `/`. `robots.txt` and `sitemap.xml` are at the domain root. `/portal.html` and `/api/` are excluded from crawlers. Search Console domain verification remains a DNS task: add the TXT token Google issues for the verified domain; no token is embedded here.

## Local checks

Run the Node tests with `node --test test-quote.cjs test-agents.cjs`. They use mocked Supabase calls and create no production leads. A successful mock test does not replace testing against the deployed preview and real Auth users.
