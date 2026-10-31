-- Terms, links and signature records. No agreement text is preloaded.
alter table public.trustlane_quote_requests
 add column pickup_address text not null default '' check(length(pickup_address)<=300),
 add column delivery_address text not null default '' check(length(delivery_address)<=300),
 add column contract_version bigint not null default 1,
 add column signed_contract_version bigint;
grant update(pickup_address,delivery_address) on public.trustlane_quote_requests to authenticated;
create table public.trustlane_agreement_terms (
 id uuid primary key default gen_random_uuid(),
 body text not null check(length(trim(body)) between 50 and 50000),
 created_by uuid not null references public.trustlane_profiles(user_id),
 created_at timestamptz not null default now()
);
alter table public.trustlane_agreement_terms enable row level security;
revoke all on public.trustlane_agreement_terms from public,anon,authenticated;
grant select on public.trustlane_agreement_terms to authenticated;
create policy agreement_terms_admin on public.trustlane_agreement_terms for select to authenticated using (public.trustlane_is_admin());
create function public.trustlane_publish_agreement_terms(p_body text) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid; begin
 if not public.trustlane_is_admin() then raise exception 'Forbidden' using errcode='42501'; end if;
 if length(trim(coalesce(p_body,''))) not between 50 and 50000 then raise exception 'Enter the approved agreement text'; end if;
 insert into public.trustlane_agreement_terms(body,created_by) values(trim(p_body),auth.uid()) returning id into result; return result;
end $$;
revoke all on function public.trustlane_publish_agreement_terms(text) from public,anon;
grant execute on function public.trustlane_publish_agreement_terms(text) to authenticated;

create table public.trustlane_booking_links (
 id uuid primary key default gen_random_uuid(), lead_id uuid not null references public.trustlane_quote_requests(id),
 quote_id uuid not null references public.trustlane_quote_drafts(id), terms_id uuid not null references public.trustlane_agreement_terms(id),
 token_hash text not null unique check(token_hash ~ '^[0-9a-f]{64}$'), created_by uuid not null references public.trustlane_profiles(user_id),
 created_at timestamptz not null default now(), expires_at timestamptz not null, version bigint not null, signed_at timestamptz
);
create index trustlane_booking_links_lead on public.trustlane_booking_links(lead_id,created_at desc);
alter table public.trustlane_booking_links enable row level security;
revoke all on public.trustlane_booking_links from public,anon,authenticated;
grant select(id,lead_id,quote_id,terms_id,created_by,created_at,expires_at,version,signed_at) on public.trustlane_booking_links to authenticated;
create policy booking_links_read on public.trustlane_booking_links for select to authenticated using (exists(select 1 from public.trustlane_quote_requests l where l.id=lead_id));
create table public.trustlane_signatures (
 id uuid primary key default gen_random_uuid(), lead_id uuid not null references public.trustlane_quote_requests(id),
 booking_link_id uuid not null unique references public.trustlane_booking_links(id), terms_id uuid not null references public.trustlane_agreement_terms(id),
 signed_name text not null, signed_at timestamptz not null default now(), signed_version bigint not null,
 agreement_body text not null, signed_snapshot jsonb not null
);
create index trustlane_signatures_lead on public.trustlane_signatures(lead_id,signed_at desc);
alter table public.trustlane_signatures enable row level security;
revoke all on public.trustlane_signatures from public,anon,authenticated;
grant select on public.trustlane_signatures to authenticated;
create policy signatures_read on public.trustlane_signatures for select to authenticated using (exists(select 1 from public.trustlane_quote_requests l where l.id=lead_id));

create function public.trustlane_bump_contract_version() returns trigger language plpgsql set search_path='' as $$
begin
 if (old.name,old.pickup,old.delivery,old.pickup_address,old.delivery_address,old.quote_amount,old.transport_type,old.vehicle_year,old.vehicle_make,old.vehicle_model,old.preferred_date,old.quote_expires_on,old.special_terms)
 is distinct from (new.name,new.pickup,new.delivery,new.pickup_address,new.delivery_address,new.quote_amount,new.transport_type,new.vehicle_year,new.vehicle_make,new.vehicle_model,new.preferred_date,new.quote_expires_on,new.special_terms)
 then new.contract_version:=old.contract_version+1; end if;
 return new;
end $$;
create trigger trustlane_contract_change before update on public.trustlane_quote_requests for each row execute function public.trustlane_bump_contract_version();
create function public.trustlane_vehicle_contract_change() returns trigger language plpgsql security definer set search_path='' as $$
begin update public.trustlane_quote_requests set contract_version=contract_version+1 where id=new.lead_id; return new; end $$;
revoke all on function public.trustlane_vehicle_contract_change() from public,anon,authenticated;
create trigger trustlane_vehicle_contract_change after insert or update on public.trustlane_vehicles for each row execute function public.trustlane_vehicle_contract_change();

create function public.trustlane_issue_booking_link(p_lead_id uuid,p_quote_id uuid,p_token_hash text) returns uuid
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); l public.trustlane_quote_requests%rowtype; q public.trustlane_quote_drafts%rowtype; terms uuid; link_id uuid; extra jsonb;
begin
 if uid is null or not exists(select 1 from public.trustlane_profiles where user_id=uid and active) then raise exception 'Forbidden' using errcode='42501'; end if;
 select * into l from public.trustlane_quote_requests where id=p_lead_id and (public.trustlane_is_admin() or assigned_to=uid) for update;
 if not found then raise exception 'Not found or forbidden' using errcode='42501'; end if;
 select * into q from public.trustlane_quote_drafts where id=p_quote_id and lead_id=l.id;
 if not found then raise exception 'Select a quote for this lead'; end if;
 if nullif(q.snapshot->>'quote_expires_on','') is not null and (q.snapshot->>'quote_expires_on')::date<current_date then raise exception 'This quote has expired'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('year',year,'make',make,'model',model) order by created_at),'[]'::jsonb) into extra from public.trustlane_vehicles where lead_id=l.id and active;
 if l.quote_amount is null or (q.snapshot->>'quote_amount')::numeric is distinct from l.quote_amount or q.snapshot->>'name' is distinct from l.name or q.snapshot->>'pickup' is distinct from l.pickup or q.snapshot->>'delivery' is distinct from l.delivery or q.snapshot->>'vehicle_year' is distinct from l.vehicle_year::text or q.snapshot->>'vehicle_make' is distinct from l.vehicle_make or q.snapshot->>'vehicle_model' is distinct from l.vehicle_model or q.snapshot->>'transport_type' is distinct from l.transport_type or q.snapshot->>'preferred_date' is distinct from l.preferred_date::text or q.snapshot->>'quote_expires_on' is distinct from l.quote_expires_on::text or q.snapshot->>'special_terms' is distinct from l.special_terms or coalesce(q.snapshot->'additional_vehicles','[]'::jsonb) is distinct from extra then raise exception 'Shipment details changed. Save a new quote draft first'; end if;
 select id into terms from public.trustlane_agreement_terms order by created_at desc,id desc limit 1;
 if terms is null then raise exception 'An administrator must publish the approved agreement terms first'; end if;
 if coalesce(p_token_hash,'') !~ '^[0-9a-f]{64}$' then raise exception 'Invalid booking token'; end if;
 insert into public.trustlane_booking_links(lead_id,quote_id,terms_id,token_hash,created_by,expires_at,version) values(l.id,q.id,terms,p_token_hash,uid,now()+interval '7 days',l.contract_version) returning id into link_id;
 return link_id;
end $$;
revoke all on function public.trustlane_issue_booking_link(uuid,uuid,text) from public,anon;
grant execute on function public.trustlane_issue_booking_link(uuid,uuid,text) to authenticated;

create function public.trustlane_public_booking_view(p_token_hash text) returns jsonb language plpgsql security definer set search_path='' as $$
declare b public.trustlane_booking_links%rowtype; l public.trustlane_quote_requests%rowtype; q public.trustlane_quote_drafts%rowtype; terms text;
begin
 select * into b from public.trustlane_booking_links where token_hash=p_token_hash and expires_at>now();
 if not found then raise exception 'Link is invalid or expired'; end if;
 select * into l from public.trustlane_quote_requests where id=b.lead_id;
 if b.signed_at is not null then return jsonb_build_object('state','signed'); end if;
 if l.contract_version<>b.version then raise exception 'Shipment details changed; request a new link'; end if;
 select * into q from public.trustlane_quote_drafts where id=b.quote_id; select body into terms from public.trustlane_agreement_terms where id=b.terms_id;
 return jsonb_build_object('state','ready','terms_id',b.terms_id,'agreement',terms,'quote',q.snapshot,'pickup_address',l.pickup_address,'delivery_address',l.delivery_address,'expires_at',b.expires_at);
end $$;
revoke all on function public.trustlane_public_booking_view(text) from public,anon,authenticated;
grant execute on function public.trustlane_public_booking_view(text) to service_role;

create function public.trustlane_public_sign_booking(p_token_hash text,p_terms_id uuid,p_name text,p_pickup_address text,p_delivery_address text,p_agreed boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare b public.trustlane_booking_links%rowtype; l public.trustlane_quote_requests%rowtype; q public.trustlane_quote_drafts%rowtype; terms text; sig uuid;
begin
 if p_agreed is distinct from true or length(trim(coalesce(p_name,''))) not between 2 and 120 or length(trim(coalesce(p_pickup_address,''))) not between 6 and 300 or length(trim(coalesce(p_delivery_address,''))) not between 6 and 300 then raise exception 'Enter your name and complete addresses and accept the agreement'; end if;
 select * into b from public.trustlane_booking_links where token_hash=p_token_hash and expires_at>now() for update;
 if not found or b.signed_at is not null then raise exception 'Link is invalid, expired or already signed'; end if;
 select * into l from public.trustlane_quote_requests where id=b.lead_id for update;
 if l.contract_version<>b.version or b.terms_id is distinct from p_terms_id then raise exception 'Shipment details changed; request a new link'; end if;
 select * into q from public.trustlane_quote_drafts where id=b.quote_id; select body into terms from public.trustlane_agreement_terms where id=b.terms_id;
 if nullif(q.snapshot->>'quote_expires_on','') is not null and (q.snapshot->>'quote_expires_on')::date<current_date then raise exception 'This quote has expired; request a new link'; end if;
 update public.trustlane_quote_requests set pickup_address=trim(p_pickup_address),delivery_address=trim(p_delivery_address) where id=l.id returning * into l;
 insert into public.trustlane_signatures(lead_id,booking_link_id,terms_id,signed_name,signed_version,agreement_body,signed_snapshot)
 values(l.id,b.id,b.terms_id,trim(p_name),l.contract_version,terms,q.snapshot||jsonb_build_object('pickup_address',l.pickup_address,'delivery_address',l.delivery_address)) returning id into sig;
 update public.trustlane_booking_links set signed_at=now() where id=b.id;
 update public.trustlane_quote_requests set signed_contract_version=l.contract_version,status='Booked',closed_outcome=null,updated_at=now() where id=l.id;
 insert into public.trustlane_orders(lead_id,created_by,quote_id,confirmation_note) values(l.id,b.created_by,b.quote_id,'Customer signed the agreement')
 on conflict(lead_id) do update set quote_id=excluded.quote_id,confirmation_note=excluded.confirmation_note,stage=case when public.trustlane_orders.stage='Cancelled' then 'Awaiting dispatch' else public.trustlane_orders.stage end,updated_at=now();
 return jsonb_build_object('success',true,'signature_id',sig);
end $$;
revoke all on function public.trustlane_public_sign_booking(text,uuid,text,text,text,boolean) from public,anon,authenticated;
grant execute on function public.trustlane_public_sign_booking(text,uuid,text,text,text,boolean) to service_role;

create table public.trustlane_booking_rate_limits (key_hash text primary key, window_started timestamptz not null, attempts integer not null check(attempts>0));
alter table public.trustlane_booking_rate_limits enable row level security;
revoke all on public.trustlane_booking_rate_limits from public,anon,authenticated;
create function public.trustlane_accept_booking(p_key text) returns boolean language plpgsql security definer set search_path='' as $$
declare attempts_count integer; begin
 if p_key is null or length(p_key) not between 1 and 200 then raise exception 'Invalid rate-limit key'; end if;
 insert into public.trustlane_booking_rate_limits as r(key_hash,window_started,attempts) values(encode(sha256(convert_to(p_key,'UTF8')),'hex'),now(),1)
 on conflict(key_hash) do update set window_started=case when now()-r.window_started>=interval '1 hour' then now() else r.window_started end, attempts=case when now()-r.window_started>=interval '1 hour' then 1 else r.attempts+1 end returning attempts into attempts_count;
 return attempts_count<=60;
end $$;
revoke all on function public.trustlane_accept_booking(text) from public,anon,authenticated;
grant execute on function public.trustlane_accept_booking(text) to service_role;
