-- Store only a one-way digest of the caller key; no raw IP address is retained.
create table public.trustlane_quote_rate_limits (
 key_hash text primary key,
 window_started timestamptz not null,
 attempts integer not null check (attempts > 0)
);
alter table public.trustlane_quote_rate_limits enable row level security;
revoke all on public.trustlane_quote_rate_limits from public, anon, authenticated;
grant all on public.trustlane_quote_rate_limits to service_role;

create function public.trustlane_accept_quote(p_key text) returns boolean
language plpgsql security definer set search_path = '' as $$
declare v_hash text; v_started timestamptz; v_attempts integer;
begin
 if p_key is null or length(p_key) < 1 or length(p_key) > 200 then
  raise exception 'Invalid rate-limit key';
 end if;
 v_hash := encode(sha256(convert_to(p_key, 'UTF8')), 'hex');
 insert into public.trustlane_quote_rate_limits as r(key_hash, window_started, attempts)
 values (v_hash, now(), 1)
 on conflict (key_hash) do update set
  window_started = case when now() - r.window_started >= interval '1 hour' then now() else r.window_started end,
  attempts = case when now() - r.window_started >= interval '1 hour' then 1 else r.attempts + 1 end
 returning window_started, attempts into v_started, v_attempts;
 if v_attempts <= 5 then return true; end if;
 return false;
end $$;
revoke all on function public.trustlane_accept_quote(text) from public, anon, authenticated;
grant execute on function public.trustlane_accept_quote(text) to service_role;
