-- Tasks remain visible only to an active administrator or the assigned agent.
create table public.trustlane_tasks (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references public.trustlane_quote_requests(id),
  created_by uuid not null references public.trustlane_profiles(user_id),
  title text not null check (length(trim(title)) between 1 and 300),
  due_on date,
  completed boolean not null default false,
  created_at timestamptz not null default now()
);
create index trustlane_tasks_lead_due on public.trustlane_tasks(lead_id, completed, due_on);
alter table public.trustlane_tasks enable row level security;
revoke all on public.trustlane_tasks from anon, authenticated;
create policy tasks_read on public.trustlane_tasks for select to authenticated
  using (exists (select 1 from public.trustlane_quote_requests l where l.id = lead_id));
create policy tasks_insert on public.trustlane_tasks for insert to authenticated
  with check (created_by = (select auth.uid()) and exists (select 1 from public.trustlane_quote_requests l where l.id = lead_id));
create policy tasks_update on public.trustlane_tasks for update to authenticated
  using (exists (select 1 from public.trustlane_quote_requests l where l.id = lead_id))
  with check (exists (select 1 from public.trustlane_quote_requests l where l.id = lead_id));
grant select on public.trustlane_tasks to authenticated;
grant insert (lead_id, created_by, title, due_on) on public.trustlane_tasks to authenticated;
grant update (completed) on public.trustlane_tasks to authenticated;

