create table public.trustlane_order_events (
 id uuid primary key default gen_random_uuid(),
 order_id uuid not null references public.trustlane_orders(id),
 actor_id uuid references public.trustlane_profiles(user_id),
 created_at timestamptz not null default now(),
 previous_stage text,
 new_stage text not null
);
create index trustlane_order_events_order on public.trustlane_order_events(order_id,created_at desc);
alter table public.trustlane_order_events enable row level security;
revoke all on public.trustlane_order_events from public, anon, authenticated;
grant select on public.trustlane_order_events to authenticated;
create policy order_events_read on public.trustlane_order_events for select to authenticated
 using (exists(select 1 from public.trustlane_orders o where o.id=order_id));
create function public.trustlane_record_order_event() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='INSERT' then
  insert into public.trustlane_order_events(order_id,actor_id,new_stage) values(new.id,auth.uid(),new.stage);
 elsif old.stage is distinct from new.stage then
  insert into public.trustlane_order_events(order_id,actor_id,previous_stage,new_stage) values(new.id,auth.uid(),old.stage,new.stage);
 end if;
 return new;
end $$;
revoke all on function public.trustlane_record_order_event() from public,anon,authenticated;
create trigger trustlane_order_event_trigger after insert or update of stage on public.trustlane_orders for each row execute function public.trustlane_record_order_event();
