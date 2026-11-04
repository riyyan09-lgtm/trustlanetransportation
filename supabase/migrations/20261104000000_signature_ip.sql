-- Preserve existing signatures; older records do not have a captured address.
alter table public.trustlane_signatures add column signer_ip inet;

-- Sign and store the address in the same transaction. Only the backend's
-- service role may call this wrapper; the browser cannot choose the address.
create function public.trustlane_public_sign_booking_with_ip(
 p_token_hash text,p_terms_id uuid,p_name text,p_pickup_address text,
 p_delivery_address text,p_agreed boolean,p_signer_ip inet
) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb; changed integer;
begin
 if p_signer_ip is null or masklen(p_signer_ip) <> (case family(p_signer_ip) when 4 then 32 else 128 end)
 then raise exception 'A valid client IP address is required'; end if;
 result := public.trustlane_public_sign_booking(p_token_hash,p_terms_id,p_name,p_pickup_address,p_delivery_address,p_agreed);
 update public.trustlane_signatures set signer_ip=p_signer_ip
 where id=(result->>'signature_id')::uuid and signer_ip is null;
 get diagnostics changed = row_count;
 if changed <> 1 then raise exception 'Could not record signature evidence'; end if;
 return result;
end $$;
revoke all on function public.trustlane_public_sign_booking_with_ip(text,uuid,text,text,text,boolean,inet) from public,anon,authenticated;
grant execute on function public.trustlane_public_sign_booking_with_ip(text,uuid,text,text,text,boolean,inet) to service_role;
