-- Manually logged contact attempts; these records do not send calls or messages.
create table public.trustlane_contact_events (
 id uuid primary key default gen_random_uuid(),
 lead_id uuid not null references public.trustlane_quote_requests(id),
 created_by uuid not null references public.trustlane_profiles(user_id),
 created_at timestamptz not null default now(),
 kind text not null check (kind in ('Call','Email','Text','Voicemail','Other')),
 outcome text not null check (length(trim(outcome)) between 1 and 160),
 details text not null default '' check (length(details) <= 2000)
);
create index trustlane_contact_events_lead on public.trustlane_contact_events(lead_id,created_at desc);
alter table public.trustlane_contact_events enable row level security;
revoke all on public.trustlane_contact_events from public, anon, authenticated;
grant select on public.trustlane_contact_events to authenticated;
grant insert(lead_id,created_by,kind,outcome,details) on public.trustlane_contact_events to authenticated;
create policy contact_events_read on public.trustlane_contact_events for select to authenticated
 using (exists(select 1 from public.trustlane_quote_requests l where l.id=lead_id));
create policy contact_events_insert on public.trustlane_contact_events for insert to authenticated
 with check (created_by=(select auth.uid()) and exists(select 1 from public.trustlane_quote_requests l where l.id=lead_id));
