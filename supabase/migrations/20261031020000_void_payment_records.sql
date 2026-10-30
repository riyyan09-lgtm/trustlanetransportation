-- Preserve an audit trail when a manual transaction record was entered in error.
alter table public.trustlane_payment_records add column voided_at timestamptz, add column voided_by uuid references public.trustlane_profiles(user_id), add column void_reason text;
create function public.trustlane_void_payment_record(p_id uuid,p_reason text) returns void
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();
begin
 if uid is null or not exists(select 1 from public.trustlane_profiles where user_id=uid and active) then raise exception 'Forbidden' using errcode='42501'; end if;
 if length(trim(coalesce(p_reason,''))) not between 1 and 500 then raise exception 'Enter a reason for voiding this record'; end if;
 update public.trustlane_payment_records p set voided_at=now(),voided_by=uid,void_reason=trim(p_reason)
 where p.id=p_id and p.voided_at is null and exists(select 1 from public.trustlane_quote_requests l where l.id=p.lead_id and (public.trustlane_is_admin() or l.assigned_to=uid));
 if not found then raise exception 'Record not found, already voided, or forbidden' using errcode='42501'; end if;
end $$;
revoke all on function public.trustlane_void_payment_record(uuid,text) from public,anon;
grant execute on function public.trustlane_void_payment_record(uuid,text) to authenticated;
