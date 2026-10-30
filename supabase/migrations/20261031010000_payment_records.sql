-- Internal record of external transactions. This does not charge or refund anyone.
create table public.trustlane_payment_records (
 id uuid primary key default gen_random_uuid(),
 lead_id uuid not null references public.trustlane_quote_requests(id),
 created_by uuid not null references public.trustlane_profiles(user_id),
 created_at timestamptz not null default now(),
 kind text not null check (kind in ('Payment','Refund','Chargeback')),
 amount numeric(12,2) not null check (amount > 0),
 transaction_date date not null,
 reference text not null default '' check (length(reference) <= 120),
 notes text not null default '' check (length(notes) <= 1000)
);
create index trustlane_payment_records_lead on public.trustlane_payment_records(lead_id,created_at desc);
alter table public.trustlane_payment_records enable row level security;
revoke all on public.trustlane_payment_records from public, anon, authenticated;
grant select on public.trustlane_payment_records to authenticated;
grant insert(lead_id,created_by,kind,amount,transaction_date,reference,notes) on public.trustlane_payment_records to authenticated;
create policy payment_records_read on public.trustlane_payment_records for select to authenticated
 using (exists(select 1 from public.trustlane_quote_requests l where l.id=lead_id));
create policy payment_records_insert on public.trustlane_payment_records for insert to authenticated
 with check (created_by=(select auth.uid()) and exists(select 1 from public.trustlane_quote_requests l where l.id=lead_id));
