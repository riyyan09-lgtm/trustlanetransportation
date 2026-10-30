-- Immutable snapshots of agent-entered quotes; no automatic delivery or booking.
create table public.trustlane_quote_drafts (
 id uuid primary key default gen_random_uuid(),
 lead_id uuid not null references public.trustlane_quote_requests(id),
 created_by uuid not null references public.trustlane_profiles(user_id),
 created_at timestamptz not null default now(),
 snapshot jsonb not null
);
create index trustlane_quote_drafts_lead on public.trustlane_quote_drafts(lead_id,created_at desc);
alter table public.trustlane_quote_drafts enable row level security;
revoke all on public.trustlane_quote_drafts from public, anon, authenticated;
grant select on public.trustlane_quote_drafts to authenticated;
create policy quote_drafts_read on public.trustlane_quote_drafts for select to authenticated
 using (exists (select 1 from public.trustlane_quote_requests l where l.id=lead_id));

create function public.trustlane_create_quote_draft(p_lead_id uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); lead public.trustlane_quote_requests%rowtype; new_id uuid;
begin
 if not exists(select 1 from public.trustlane_profiles where user_id=uid and active) then raise exception 'Forbidden' using errcode='42501'; end if;
 select * into lead from public.trustlane_quote_requests where id=p_lead_id and (public.trustlane_is_admin() or assigned_to=uid);
 if not found then raise exception 'Not found or forbidden' using errcode='42501'; end if;
 if lead.quote_amount is null then raise exception 'Enter and save a customer quote amount first'; end if;
 insert into public.trustlane_quote_drafts(lead_id,created_by,snapshot) values(lead.id,uid,
 jsonb_build_object('name',lead.name,'pickup',lead.pickup,'delivery',lead.delivery,'vehicle_year',lead.vehicle_year,
 'vehicle_make',lead.vehicle_make,'vehicle_model',lead.vehicle_model,'preferred_date',lead.preferred_date,
 'transport_type',lead.transport_type,'quote_amount',lead.quote_amount,'quote_expires_on',lead.quote_expires_on,'special_terms',lead.special_terms))
 returning id into new_id;
 return new_id;
end $$;
revoke all on function public.trustlane_create_quote_draft(uuid) from public, anon;
grant execute on function public.trustlane_create_quote_draft(uuid) to authenticated;
