-- Do not issue an invoice for an outdated signed agreement.
create or replace function public.trustlane_create_invoice(p_order_id uuid,p_due_on date default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); ord public.trustlane_orders%rowtype; lead public.trustlane_quote_requests%rowtype; snap jsonb; invoice_id uuid;
begin
 if uid is null or not exists(select 1 from public.trustlane_profiles where user_id=uid and active) then raise exception 'Forbidden' using errcode='42501'; end if;
 select o.* into ord from public.trustlane_orders o join public.trustlane_quote_requests l on l.id=o.lead_id where o.id=p_order_id and (public.trustlane_is_admin() or l.assigned_to=uid);
 if not found then raise exception 'Not found or forbidden' using errcode='42501'; end if;
 select * into lead from public.trustlane_quote_requests where id=ord.lead_id and (public.trustlane_is_admin() or assigned_to=uid) for update;
 if not found then raise exception 'Not found or forbidden' using errcode='42501'; end if;
 select * into ord from public.trustlane_orders where id=p_order_id;
 if ord.stage='Cancelled' then raise exception 'Cannot invoice a cancelled order'; end if;
 if lead.signed_contract_version is not null and lead.signed_contract_version<>lead.contract_version then raise exception 'Shipment changed after signing; the customer must sign the updated agreement before invoicing'; end if;
 select snapshot into snap from public.trustlane_quote_drafts where id=ord.quote_id and lead_id=ord.lead_id;
 if snap is null or snap->>'quote_amount' is null then raise exception 'Order quote is unavailable'; end if;
 insert into public.trustlane_invoices(order_id,created_by,due_on,snapshot) values(ord.id,uid,p_due_on,snap) returning id into invoice_id; return invoice_id;
end $$;
