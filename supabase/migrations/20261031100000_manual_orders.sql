-- Orders entered by the team after an external customer confirmation.
-- This workflow does not schedule a carrier or collect a signature or payment.
create table public.trustlane_orders (
 id uuid primary key default gen_random_uuid(),
 lead_id uuid not null unique references public.trustlane_quote_requests(id),
 created_by uuid not null references public.trustlane_profiles(user_id),
 created_at timestamptz not null default now(),
 quote_id uuid not null references public.trustlane_quote_drafts(id),
 confirmation_note text not null check(length(trim(confirmation_note)) between 5 and 1000),
 stage text not null default 'Awaiting dispatch' check(stage in ('Awaiting dispatch','Carrier assigned','Dispatched','Picked up','In transit','Delivered','Cancelled')),
 updated_at timestamptz not null default now()
);
create index trustlane_orders_quote_id on public.trustlane_orders(quote_id);
alter table public.trustlane_orders enable row level security;
revoke all on public.trustlane_orders from public, anon, authenticated;
grant select on public.trustlane_orders to authenticated;
create policy orders_read on public.trustlane_orders for select to authenticated
 using (exists(select 1 from public.trustlane_quote_requests l where l.id=lead_id));

create function public.trustlane_record_manual_order(p_lead_id uuid, p_quote_id uuid, p_confirmation_note text, p_confirmed boolean) returns uuid
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); order_id uuid;
begin
 if uid is null or not exists(select 1 from public.trustlane_profiles where user_id=uid and active) then raise exception 'Forbidden' using errcode='42501'; end if;
 if p_confirmed is distinct from true or length(trim(coalesce(p_confirmation_note,''))) not between 5 and 1000 then raise exception 'Confirm the customer agreement and enter how it was confirmed'; end if;
 perform 1 from public.trustlane_quote_requests l where l.id=p_lead_id and (public.trustlane_is_admin() or l.assigned_to=uid) for update;
 if not found then raise exception 'Not found or forbidden' using errcode='42501'; end if;
 if not exists(select 1 from public.trustlane_quote_drafts q where q.id=p_quote_id and q.lead_id=p_lead_id) then raise exception 'Select a quote for this lead'; end if;
 insert into public.trustlane_orders(lead_id,created_by,quote_id,confirmation_note) values(p_lead_id,uid,p_quote_id,trim(p_confirmation_note)) returning id into order_id;
 update public.trustlane_quote_requests set status='Booked',closed_outcome=null,updated_at=now() where id=p_lead_id;
 return order_id;
end $$;
revoke all on function public.trustlane_record_manual_order(uuid,uuid,text,boolean) from public, anon;
grant execute on function public.trustlane_record_manual_order(uuid,uuid,text,boolean) to authenticated;

create function public.trustlane_update_order_stage(p_order_id uuid,p_stage text) returns void
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();
begin
 if uid is null or not exists(select 1 from public.trustlane_profiles where user_id=uid and active) then raise exception 'Forbidden' using errcode='42501'; end if;
 if p_stage is null or p_stage not in ('Awaiting dispatch','Carrier assigned','Dispatched','Picked up','In transit','Delivered','Cancelled') then raise exception 'Invalid order stage'; end if;
 update public.trustlane_orders o set stage=p_stage,updated_at=now() where o.id=p_order_id and exists(select 1 from public.trustlane_quote_requests l where l.id=o.lead_id and (public.trustlane_is_admin() or l.assigned_to=uid));
 if not found then raise exception 'Not found or forbidden' using errcode='42501'; end if;
end $$;
revoke all on function public.trustlane_update_order_stage(uuid,text) from public, anon;
grant execute on function public.trustlane_update_order_stage(uuid,text) to authenticated;

-- A status change must not create the appearance of a booking by itself.
create or replace function public.trustlane_update_lead(p_id uuid, p_status text, p_outcome text default null, p_assignee uuid default null, p_change_assignment boolean default false) returns void language plpgsql security definer set search_path = '' as $$
declare is_admin boolean; uid uuid; begin
 uid := auth.uid(); is_admin := public.trustlane_is_admin();
 if uid is null or not exists(select 1 from public.trustlane_profiles where user_id=uid and active) then raise exception 'Forbidden' using errcode='42501'; end if;
 if not exists(select 1 from public.trustlane_quote_requests where id=p_id and (is_admin or assigned_to=uid)) then raise exception 'Not found or forbidden' using errcode='42501'; end if;
 if p_status not in ('New','Assigned','Contacted','Quoted','Booked','Closed') or p_status is null then raise exception 'Invalid status'; end if;
 if p_change_assignment and not is_admin then raise exception 'Forbidden' using errcode='42501'; end if;
 if p_change_assignment and p_assignee is not null and not exists(select 1 from public.trustlane_profiles where user_id=p_assignee and role='agent' and active) then raise exception 'Invalid assignee'; end if;
 if length(coalesce(p_outcome,''))>200 then raise exception 'Outcome too long'; end if;
 if p_status='Booked' and exists(select 1 from public.trustlane_quote_requests where id=p_id and status<>'Booked') and not exists(select 1 from public.trustlane_orders where lead_id=p_id) then raise exception 'Record the customer-confirmed order first'; end if;
 update public.trustlane_quote_requests set status=p_status, closed_outcome=case when p_status='Closed' then nullif(trim(p_outcome),'') else null end, assigned_to=case when p_change_assignment then p_assignee else assigned_to end, updated_at=now()
 where id=p_id and (is_admin or assigned_to=uid);
 if not found then raise exception 'Not found or forbidden' using errcode='42501'; end if;
end $$;
