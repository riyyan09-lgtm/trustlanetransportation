-- Record material changes without copying customer contact information.
create table public.trustlane_lead_activity (
 id uuid primary key default gen_random_uuid(),
 lead_id uuid not null references public.trustlane_quote_requests(id),
 actor_id uuid references public.trustlane_profiles(user_id),
 occurred_at timestamptz not null default now(),
 changes jsonb not null
);
create index trustlane_activity_lead_time on public.trustlane_lead_activity(lead_id, occurred_at desc);
alter table public.trustlane_lead_activity enable row level security;
revoke all on public.trustlane_lead_activity from public, anon, authenticated;
grant select on public.trustlane_lead_activity to authenticated;
create policy activity_read on public.trustlane_lead_activity for select to authenticated
 using (exists (select 1 from public.trustlane_quote_requests l where l.id=lead_id));

create function public.trustlane_record_lead_activity() returns trigger
language plpgsql security definer set search_path = '' as $$
declare changes jsonb := '{}'::jsonb; key text; before_row jsonb; after_row jsonb;
begin
 before_row := to_jsonb(old); after_row := to_jsonb(new);
 foreach key in array array['status','closed_outcome','assigned_to','working_status','transport_type','quote_amount','carrier_pay','quote_expires_on','desired_delivery_on'] loop
  if before_row->key is distinct from after_row->key then
   changes := changes || jsonb_build_object(key,jsonb_build_object('from',before_row->key,'to',after_row->key));
  end if;
 end loop;
 if changes <> '{}'::jsonb then
  insert into public.trustlane_lead_activity(lead_id,actor_id,changes)
  values(new.id,case when exists(select 1 from public.trustlane_profiles where user_id=auth.uid()) then auth.uid() else null end,changes);
 end if;
 return new;
end $$;
revoke all on function public.trustlane_record_lead_activity() from public, anon, authenticated;
create trigger trustlane_lead_activity_trigger after update on public.trustlane_quote_requests
 for each row execute function public.trustlane_record_lead_activity();

