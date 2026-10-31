create table public.trustlane_message_templates (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references public.trustlane_profiles(user_id),
 title text not null check (char_length(trim(title)) between 1 and 120),
 body text not null check (char_length(trim(body)) between 1 and 5000),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table public.trustlane_message_templates enable row level security;
grant select, insert, update, delete on public.trustlane_message_templates to authenticated;
create policy templates_owner on public.trustlane_message_templates for all to authenticated
 using (owner_id = (select auth.uid()) and exists(select 1 from public.trustlane_profiles p where p.user_id=(select auth.uid()) and p.active))
 with check (owner_id = (select auth.uid()) and exists(select 1 from public.trustlane_profiles p where p.user_id=(select auth.uid()) and p.active));

