-- Manual CRM entry assigns an agent's new lead to that same agent.
create function public.trustlane_create_manual_lead(p_lead jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); profile_role text; new_id uuid;
begin
 select role into profile_role from public.trustlane_profiles where user_id=uid and active;
 if profile_role is null then raise exception 'Forbidden' using errcode='42501'; end if;
 if jsonb_typeof(p_lead) <> 'object' or coalesce(p_lead->>'email','') !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
  raise exception 'Enter a valid email address';
 end if;
 insert into public.trustlane_quote_requests(request_id,name,email,phone,pickup,delivery,vehicle_year,vehicle_make,vehicle_model,preferred_date,details,assigned_to,status)
 values(gen_random_uuid(), trim(p_lead->>'name'), trim(p_lead->>'email'), trim(p_lead->>'phone'), trim(p_lead->>'pickup'), trim(p_lead->>'delivery'),
  (p_lead->>'vehicle_year')::integer, trim(p_lead->>'vehicle_make'), trim(p_lead->>'vehicle_model'), (p_lead->>'preferred_date')::date,
  coalesce(trim(p_lead->>'details'),''), case when profile_role='agent' then uid else null end, case when profile_role='agent' then 'Assigned' else 'New' end)
 returning id into new_id;
 return new_id;
end $$;
revoke all on function public.trustlane_create_manual_lead(jsonb) from public, anon;
grant execute on function public.trustlane_create_manual_lead(jsonb) to authenticated;
