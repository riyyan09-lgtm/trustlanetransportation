-- Additional vehicles complement, rather than replace, the vehicle submitted with the lead.
create table public.trustlane_vehicles (
 id uuid primary key default gen_random_uuid(),
 lead_id uuid not null references public.trustlane_quote_requests(id),
 created_by uuid not null references public.trustlane_profiles(user_id),
 created_at timestamptz not null default now(),
 year integer check (year is null or year between 1886 and 2100),
 make text not null check (length(trim(make)) between 1 and 80),
 model text not null check (length(trim(model)) between 1 and 80),
 vin text not null default '' check (length(vin) <= 17),
 vehicle_type text not null default '' check (length(vehicle_type) <= 80),
 color text not null default '' check (length(color) <= 80),
 condition text not null default '' check (length(condition) <= 300),
 keys_available text not null default '' check (keys_available in ('','Yes','No','Unknown')),
 carrier_notes text not null default '' check (length(carrier_notes) <= 2000),
 active boolean not null default true
);
create index trustlane_vehicles_lead on public.trustlane_vehicles(lead_id,created_at);
alter table public.trustlane_vehicles enable row level security;
revoke all on public.trustlane_vehicles from public, anon, authenticated;
grant select on public.trustlane_vehicles to authenticated;
grant insert(lead_id,created_by,year,make,model,vin,vehicle_type,color,condition,keys_available,carrier_notes) on public.trustlane_vehicles to authenticated;
grant update(year,make,model,vin,vehicle_type,color,condition,keys_available,carrier_notes,active) on public.trustlane_vehicles to authenticated;
create policy vehicles_read on public.trustlane_vehicles for select to authenticated using (exists(select 1 from public.trustlane_quote_requests l where l.id=lead_id));
create policy vehicles_insert on public.trustlane_vehicles for insert to authenticated with check (created_by=(select auth.uid()) and exists(select 1 from public.trustlane_quote_requests l where l.id=lead_id));
create policy vehicles_update on public.trustlane_vehicles for update to authenticated using (exists(select 1 from public.trustlane_quote_requests l where l.id=lead_id)) with check (exists(select 1 from public.trustlane_quote_requests l where l.id=lead_id));

create or replace function public.trustlane_create_quote_draft(p_lead_id uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); lead public.trustlane_quote_requests%rowtype; new_id uuid; extra jsonb;
begin
 if not exists(select 1 from public.trustlane_profiles where user_id=uid and active) then raise exception 'Forbidden' using errcode='42501'; end if;
 select * into lead from public.trustlane_quote_requests where id=p_lead_id and (public.trustlane_is_admin() or assigned_to=uid);
 if not found then raise exception 'Not found or forbidden' using errcode='42501'; end if;
 if lead.quote_amount is null then raise exception 'Enter and save a customer quote amount first'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('year',year,'make',make,'model',model) order by created_at),'[]'::jsonb) into extra from public.trustlane_vehicles where lead_id=lead.id and active;
 insert into public.trustlane_quote_drafts(lead_id,created_by,snapshot) values(lead.id,uid,
 jsonb_build_object('name',lead.name,'pickup',lead.pickup,'delivery',lead.delivery,'vehicle_year',lead.vehicle_year,
 'vehicle_make',lead.vehicle_make,'vehicle_model',lead.vehicle_model,'additional_vehicles',extra,'preferred_date',lead.preferred_date,
 'transport_type',lead.transport_type,'quote_amount',lead.quote_amount,'quote_expires_on',lead.quote_expires_on,'special_terms',lead.special_terms))
 returning id into new_id; return new_id;
end $$;
