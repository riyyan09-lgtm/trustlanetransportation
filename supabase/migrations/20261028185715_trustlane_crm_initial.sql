-- New Trustlane CRM data; does not alter the legacy tables.
create table public.trustlane_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null check (length(trim(display_name)) between 1 and 120),
 role text not null check (role in ('admin','agent')),
 active boolean not null default true
);
create table public.trustlane_quote_requests (
 id uuid primary key default gen_random_uuid(),
 request_id uuid not null unique,
 name text not null check (length(trim(name)) between 2 and 120),
 email text not null check (length(email) between 5 and 254),
 phone text not null check (length(phone) between 7 and 40),
 pickup text not null check (length(trim(pickup)) between 2 and 160),
 delivery text not null check (length(trim(delivery)) between 2 and 160),
 vehicle_year integer not null check (vehicle_year between 1886 and 2100),
 vehicle_make text not null check (length(trim(vehicle_make)) between 1 and 80),
 vehicle_model text not null check (length(trim(vehicle_model)) between 1 and 80),
 preferred_date date not null,
 details text not null default '' check (length(details) <= 2000),
 status text not null default 'New' check (status in ('New','Assigned','Contacted','Quoted','Booked','Closed')),
 closed_outcome text check (closed_outcome is null or length(closed_outcome) <= 200),
 assigned_to uuid references public.trustlane_profiles(user_id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index trustlane_quote_assignee_created on public.trustlane_quote_requests(assigned_to,created_at desc);
create table public.trustlane_notes (
 id uuid primary key default gen_random_uuid(),
 lead_id uuid not null references public.trustlane_quote_requests(id),
 author_id uuid not null references public.trustlane_profiles(user_id),
 body text not null check (length(trim(body)) between 1 and 4000),
 created_at timestamptz not null default now()
);
create index trustlane_notes_lead_created on public.trustlane_notes(lead_id,created_at);
alter table public.trustlane_profiles enable row level security;
alter table public.trustlane_quote_requests enable row level security;
alter table public.trustlane_notes enable row level security;
revoke all on public.trustlane_profiles, public.trustlane_quote_requests, public.trustlane_notes from anon, authenticated;
create function public.trustlane_is_admin() returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.trustlane_profiles where user_id = (select auth.uid()) and role='admin' and active)
$$;
revoke all on function public.trustlane_is_admin() from public, anon;
grant execute on function public.trustlane_is_admin() to authenticated;
create policy profiles_read on public.trustlane_profiles for select to authenticated using (user_id = (select auth.uid()) or public.trustlane_is_admin());
create policy leads_read on public.trustlane_quote_requests for select to authenticated using (public.trustlane_is_admin() or (assigned_to = (select auth.uid()) and exists (select 1 from public.trustlane_profiles p where p.user_id=(select auth.uid()) and p.active)));
create policy notes_read on public.trustlane_notes for select to authenticated using (exists (select 1 from public.trustlane_quote_requests l where l.id=lead_id));
create policy notes_insert on public.trustlane_notes for insert to authenticated with check (author_id=(select auth.uid()) and exists (select 1 from public.trustlane_quote_requests l where l.id=lead_id));
grant select on public.trustlane_profiles, public.trustlane_quote_requests, public.trustlane_notes to authenticated;
grant insert (lead_id, author_id, body) on public.trustlane_notes to authenticated;
create function public.trustlane_update_lead(p_id uuid, p_status text, p_outcome text default null, p_assignee uuid default null, p_change_assignment boolean default false) returns void language plpgsql security definer set search_path = '' as $$
declare is_admin boolean; uid uuid; begin
 uid := auth.uid(); is_admin := public.trustlane_is_admin();
 if uid is null or not exists(select 1 from public.trustlane_profiles where user_id=uid and active) then raise exception 'Forbidden' using errcode='42501'; end if;
 if p_status not in ('New','Assigned','Contacted','Quoted','Booked','Closed') or p_status is null then raise exception 'Invalid status'; end if;
 if p_change_assignment and not is_admin then raise exception 'Forbidden' using errcode='42501'; end if;
 if p_change_assignment and p_assignee is not null and not exists(select 1 from public.trustlane_profiles where user_id=p_assignee and role='agent' and active) then raise exception 'Invalid assignee'; end if;
 if length(coalesce(p_outcome,''))>200 then raise exception 'Outcome too long'; end if;
 update public.trustlane_quote_requests set status=p_status, closed_outcome=case when p_status='Closed' then nullif(trim(p_outcome),'') else null end, assigned_to=case when p_change_assignment then p_assignee else assigned_to end, updated_at=now()
 where id=p_id and (is_admin or assigned_to=uid);
 if not found then raise exception 'Not found or forbidden' using errcode='42501'; end if;
end $$;
revoke all on function public.trustlane_update_lead(uuid,text,text,uuid,boolean) from public, anon;
grant execute on function public.trustlane_update_lead(uuid,text,text,uuid,boolean) to authenticated;

