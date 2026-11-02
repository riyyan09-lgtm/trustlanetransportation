-- Synthetic records only. Every change is rolled back.
begin;
insert into auth.users(id,email) values
 ('a1111111-1111-4111-8111-111111111111','assignment-a@example.invalid'),
 ('b2222222-2222-4222-8222-222222222222','assignment-b@example.invalid'),
 ('e3333333-3333-4333-8333-333333333333','assignment-admin@example.invalid');
insert into public.trustlane_profiles(user_id,display_name,role,active) values
 ('a1111111-1111-4111-8111-111111111111','TEST AGENT A','agent',true),
 ('b2222222-2222-4222-8222-222222222222','TEST AGENT B','agent',true),
 ('e3333333-3333-4333-8333-333333333333','TEST ADMIN','admin',true);
insert into public.trustlane_quote_requests(id,request_id,name,email,phone,pickup,delivery,vehicle_year,vehicle_make,vehicle_model,preferred_date)
values ('c4444444-4444-4444-8444-444444444444',gen_random_uuid(),'TEST ASSIGNMENT','assignment@example.invalid','2025550142','Test origin','Test destination',2022,'Test','Vehicle',current_date);
set local role authenticated;
select set_config('request.jwt.claim.sub','e3333333-3333-4333-8333-333333333333',true);
do $$ begin
 if not exists(select 1 from public.trustlane_quote_requests where id='c4444444-4444-4444-8444-444444444444') then raise exception 'Admin inbox missing new lead'; end if;
end $$;
select public.trustlane_update_lead('c4444444-4444-4444-8444-444444444444','Assigned',null,'a1111111-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claim.sub','a1111111-1111-4111-8111-111111111111',true);
do $$ begin
 if not exists(select 1 from public.trustlane_quote_requests where id='c4444444-4444-4444-8444-444444444444' and status='Assigned') then raise exception 'Assigned agent cannot see lead'; end if;
end $$;
select public.trustlane_update_lead('c4444444-4444-4444-8444-444444444444','Contacted',null,null,false);
select set_config('request.jwt.claim.sub','b2222222-2222-4222-8222-222222222222',true);
do $$ begin
 if exists(select 1 from public.trustlane_quote_requests where id='c4444444-4444-4444-8444-444444444444') then raise exception 'Unassigned agent can see lead'; end if;
 begin
  perform public.trustlane_update_lead('c4444444-4444-4444-8444-444444444444','Closed','test',null,false);
  raise exception 'Unassigned agent updated lead';
 exception when insufficient_privilege then null; end;
end $$;
rollback;
select 'lead assignment and isolation checks passed; test data rolled back' as result;

