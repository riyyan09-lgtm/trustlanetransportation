-- Proposed immediate containment. NOT applied. This blocks existing direct
-- anon/authenticated client access to these tables and views; service-role
-- server access is unaffected. Confirm existing integrations before use.
begin;
alter table public.leads enable row level security;
alter table public.bookings enable row level security;
alter table public.lead_alerts enable row level security;
revoke all privileges on public.recent_leads from anon, authenticated;
revoke all privileges on public.lead_alert_status from anon, authenticated;
commit;

