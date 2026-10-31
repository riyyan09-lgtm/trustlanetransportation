-- Immutable invoice snapshots; creating an invoice does not collect payment.
create table public.trustlane_invoices (
 id uuid primary key default gen_random_uuid(),
 order_id uuid not null references public.trustlane_orders(id),
 created_by uuid not null references public.trustlane_profiles(user_id),
 issued_on date not null default current_date,
 due_on date,
 created_at timestamptz not null default now(),
 snapshot jsonb not null
);
create index trustlane_invoices_order on public.trustlane_invoices(order_id,created_at desc);
alter table public.trustlane_invoices enable row level security;
revoke all on public.trustlane_invoices from public, anon, authenticated;
grant select on public.trustlane_invoices to authenticated;
create policy invoices_read on public.trustlane_invoices for select to authenticated
 using (exists(select 1 from public.trustlane_orders o where o.id=order_id));
create function public.trustlane_create_invoice(p_order_id uuid,p_due_on date default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); ord public.trustlane_orders%rowtype; snap jsonb; invoice_id uuid;
begin
 if uid is null or not exists(select 1 from public.trustlane_profiles where user_id=uid and active) then raise exception 'Forbidden' using errcode='42501'; end if;
 select o.* into ord from public.trustlane_orders o join public.trustlane_quote_requests l on l.id=o.lead_id
 where o.id=p_order_id and (public.trustlane_is_admin() or l.assigned_to=uid);
 if not found then raise exception 'Not found or forbidden' using errcode='42501'; end if;
 if ord.stage='Cancelled' then raise exception 'Cannot invoice a cancelled order'; end if;
 select snapshot into snap from public.trustlane_quote_drafts where id=ord.quote_id and lead_id=ord.lead_id;
 if snap is null or snap->>'quote_amount' is null then raise exception 'Order quote is unavailable'; end if;
 insert into public.trustlane_invoices(order_id,created_by,due_on,snapshot) values(ord.id,uid,p_due_on,snap) returning id into invoice_id;
 return invoice_id;
end $$;
revoke all on function public.trustlane_create_invoice(uuid,date) from public,anon;
grant execute on function public.trustlane_create_invoice(uuid,date) to authenticated;
