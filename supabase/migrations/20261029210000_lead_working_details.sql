-- Agent-editable working details; quote requests and assignments remain intact.
alter table public.trustlane_quote_requests
  add column working_status text not null default '' check (length(working_status) <= 80),
  add column transport_type text not null default '' check (transport_type in ('', 'Open', 'Enclosed')),
  add column quote_amount numeric(12,2) check (quote_amount is null or quote_amount >= 0),
  add column carrier_pay numeric(12,2) check (carrier_pay is null or carrier_pay >= 0),
  add column quote_expires_on date,
  add column desired_delivery_on date,
  add column reference_number text not null default '' check (length(reference_number) <= 120),
  add column special_terms text not null default '' check (length(special_terms) <= 2000),
  add constraint trustlane_carrier_pay_limit check (carrier_pay is null or quote_amount is null or carrier_pay <= quote_amount);

create policy leads_working_update on public.trustlane_quote_requests for update to authenticated
using (public.trustlane_is_admin() or (assigned_to = (select auth.uid()) and exists (select 1 from public.trustlane_profiles p where p.user_id=(select auth.uid()) and p.active)))
with check (public.trustlane_is_admin() or (assigned_to = (select auth.uid()) and exists (select 1 from public.trustlane_profiles p where p.user_id=(select auth.uid()) and p.active)));

grant update (name,email,phone,pickup,delivery,vehicle_year,vehicle_make,vehicle_model,preferred_date,details,working_status,transport_type,quote_amount,carrier_pay,quote_expires_on,desired_delivery_on,reference_number,special_terms) on public.trustlane_quote_requests to authenticated;

