# Trustlane deployment and operations

## Current deployment state

The Trustlane site and portal source are on the `trustlane-preview` branch of `riyyan09-lgtm/trustlanetransportation`. Vercel reports the latest preview deployment as complete. Production is intentionally unchanged while the existing ShipGrid integration and quote workflow are checked. Preview needs the server environment variables below before portal sign-in or live quote storage can be verified. The production Vercel project already has Supabase server credentials; keep those values unchanged.

## Vercel environment

Configure these variables in the Vercel project for Preview and Production. Use the existing project values for the Supabase URL, anon key, and service-role key; do not add them to Git. `SITE_URL` should match the deployed canonical domain. The service-role key must be available to server functions only; never prefix it with `NEXT_PUBLIC_`. The quote form includes a hidden honeypot, request idempotency, server validation, and a database-backed per-IP limit of five requests per hour. The database stores a one-way digest, not the raw IP address. No third-party CAPTCHA, email, SMS, or scheduling credentials are required by this version.

Required server variables:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` (or existing `NEXT_PUBLIC_SUPABASE_ANON_KEY`)
- `SUPABASE_SERVICE_ROLE_KEY`
- `SITE_URL`

## First administrator and agents

1. In the correct Supabase project, open **Authentication → Users** and check whether the administrator account already exists. Do not reset or change its password.
2. If it does not exist, create the user using the administrator's intended email and existing chosen password. Verify the email through Supabase's user management flow.
3. Copy that user's UUID from Auth → Users. In the Supabase SQL editor, insert its portal profile:

```sql
insert into public.trustlane_profiles (user_id, display_name, role, active)
values ('<AUTH_USER_UUID>', '<ADMIN_DISPLAY_NAME>', 'admin', true);
```

4. Sign in at `/portal.html`. Use **Manage agents** to invite agents after Supabase Auth email delivery and the `/portal.html` redirect allowlist are configured.
5. Admins can assign and reassign leads, manage lead statuses, and deactivate/reactivate agent profiles. Agents only see leads assigned to their own account. Database RLS and the status RPC enforce this boundary.

Do not promote a profile to admin unless you have verified the Auth account belongs to the intended administrator. Invite delivery depends on the Supabase Auth SMTP setup; no email provider has been configured by this project.

## Database and data

Migrations are in `supabase/migrations/`. They create isolated `trustlane_*` CRM tables, role-aware RLS, status management, and quote rate limiting. No legacy records were copied. The existing `leads`, `bookings`, and `lead_alerts` tables had no rows at inspection time. Legacy RLS was enabled and anonymous/authenticated access to those tables and the `recent_leads` and `lead_alert_status` views was revoked. This can interrupt any existing browser-based integration using those objects; confirm the existing ShipGrid endpoint before switching production traffic. Service-role access is unchanged.

## Search indexing

Public search content is the homepage at `/`. `robots.txt` and `sitemap.xml` are at the domain root. `/portal.html` and `/api/` are excluded from crawlers. Search Console domain verification remains a DNS task: add the TXT token Google issues for the verified domain; no token is embedded here.

## Local checks

Run the Node tests with `node --test test-quote.cjs test-agents.cjs`. They use mocked Supabase calls and create no production leads. A successful mock test does not replace testing against the deployed preview and real Auth users.