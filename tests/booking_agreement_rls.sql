-- Synthetic accounts, terms, booking links and signatures are rolled back.
begin;
insert into auth.users(id,email) values ('aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa','booking-test-a@example.invalid'),('bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb','booking-test-b@example.invalid'),('eeeeeeee-eeee-4eee-eeee-eeeeeeeeeeee','booking-test-admin@example.invalid');
insert into public.trustlane_profiles(user_id,display_name,role,active) values ('aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa','TEST AGENT A','agent',true),('bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb','TEST AGENT B','agent',true),('eeeeeeee-eeee-4eee-eeee-eeeeeeeeeeee','TEST ADMIN','admin',true);
insert into public.trustlane_quote_requests(id,request_id,name,email,phone,pickup,delivery,vehicle_year,vehicle_make,vehicle_model,preferred_date,assigned_to,quote_amount) values ('cccccccc-cccc-4ccc-cccc-cccccccccccc',gen_random_uuid(),'TEST BOOKING','booking-test@example.invalid','5555550100','Test pickup','Test delivery',2020,'Test','Vehicle',current_date,'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa',900);
set local role authenticated;
select set_config('request.jwt.claim.sub','eeeeeeee-eeee-4eee-eeee-eeeeeeeeeeee',true);
select set_config('test.terms',public.trustlane_publish_agreement_terms(repeat('TEST TERMS ONLY ',5))::text,true);
select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa',true);
select set_config('test.quote',public.trustlane_create_quote_draft('cccccccc-cccc-4ccc-cccc-cccccccccccc')::text,true);
select public.trustlane_issue_booking_link('cccccccc-cccc-4ccc-cccc-cccccccccccc',current_setting('test.quote')::uuid,repeat('1',64));
do $$ begin
 begin perform public.trustlane_public_booking_view(repeat('1',64)); raise exception 'Authenticated user could call service function'; exception when insufficient_privilege then null; end;
end $$;
set local role service_role;
do $$ begin
 for n in 1..60 loop if not public.trustlane_accept_booking('booking-test-only') then raise exception 'Rate limit blocked too early'; end if; end loop;
 if public.trustlane_accept_booking('booking-test-only') then raise exception 'Rate limit did not block'; end if;
 if public.trustlane_public_booking_view(repeat('1',64))->>'state'<>'ready' then raise exception 'Link view failed'; end if;
 begin perform public.trustlane_public_sign_booking(repeat('1',64),current_setting('test.terms')::uuid,'Test signer','123 Test pickup','456 Test delivery',false); raise exception 'Signature without consent allowed'; exception when raise_exception then if sqlerrm='Signature without consent allowed' then raise; end if; end;
 if (public.trustlane_public_sign_booking(repeat('1',64),current_setting('test.terms')::uuid,'Test signer','123 Test pickup','456 Test delivery',true)->>'success')::boolean is not true then raise exception 'Signing failed'; end if;
 begin perform public.trustlane_public_sign_booking(repeat('1',64),current_setting('test.terms')::uuid,'Test signer','123 Test pickup','456 Test delivery',true); raise exception 'Replay allowed'; exception when raise_exception then if sqlerrm='Replay allowed' then raise; end if; end;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa',true);
do $$ begin
 if not exists(select 1 from public.trustlane_quote_requests where id='cccccccc-cccc-4ccc-cccc-cccccccccccc' and status='Booked' and contract_version=signed_contract_version) then raise exception 'Signed lead not booked'; end if;
 if (select count(*) from public.trustlane_orders where lead_id='cccccccc-cccc-4ccc-cccc-cccccccccccc')<>1 then raise exception 'Signed order missing'; end if;
 if not exists(select 1 from public.trustlane_signatures where lead_id='cccccccc-cccc-4ccc-cccc-cccccccccccc' and signed_snapshot->>'pickup_address'='123 Test pickup' and agreement_body like 'TEST TERMS%') then raise exception 'Signature snapshot missing'; end if;
 begin update public.trustlane_quote_requests set signed_contract_version=999 where id='cccccccc-cccc-4ccc-cccc-cccccccccccc'; raise exception 'Agent could forge signature version'; exception when insufficient_privilege then null; end;
end $$;
update public.trustlane_quote_requests set quote_amount=1000 where id='cccccccc-cccc-4ccc-cccc-cccccccccccc';
do $$ begin
 if not exists(select 1 from public.trustlane_quote_requests where id='cccccccc-cccc-4ccc-cccc-cccccccccccc' and contract_version<>signed_contract_version) then raise exception 'Price did not open agreement'; end if;
 begin perform public.trustlane_create_invoice((select id from public.trustlane_orders where lead_id='cccccccc-cccc-4ccc-cccc-cccccccccccc'),null); raise exception 'Stale agreement invoice allowed'; exception when raise_exception then if sqlerrm='Stale agreement invoice allowed' then raise; end if; end;
 begin perform public.trustlane_issue_booking_link('cccccccc-cccc-4ccc-cccc-cccccccccccc',current_setting('test.quote')::uuid,repeat('2',64)); raise exception 'Stale quote allowed'; exception when raise_exception then if sqlerrm='Stale quote allowed' then raise; end if; end;
end $$;
select set_config('test.quote',public.trustlane_create_quote_draft('cccccccc-cccc-4ccc-cccc-cccccccccccc')::text,true);
select public.trustlane_issue_booking_link('cccccccc-cccc-4ccc-cccc-cccccccccccc',current_setting('test.quote')::uuid,repeat('2',64));
update public.trustlane_quote_requests set pickup_address='789 Changed address' where id='cccccccc-cccc-4ccc-cccc-cccccccccccc';
set local role service_role;
do $$ begin begin perform public.trustlane_public_booking_view(repeat('2',64)); raise exception 'Stale address link allowed'; exception when raise_exception then if sqlerrm='Stale address link allowed' then raise; end if; end; end $$;
set local role authenticated; select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa',true);
select public.trustlane_issue_booking_link('cccccccc-cccc-4ccc-cccc-cccccccccccc',current_setting('test.quote')::uuid,repeat('3',64));
set local role service_role;
select public.trustlane_public_sign_booking(repeat('3',64),current_setting('test.terms')::uuid,'Test signer','789 Changed address','456 Test delivery',true);
set local role authenticated; select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa',true);
select public.trustlane_issue_booking_link('cccccccc-cccc-4ccc-cccc-cccccccccccc',current_setting('test.quote')::uuid,repeat('5',64));
reset role; update public.trustlane_booking_links set expires_at=now()-interval '1 second' where token_hash=repeat('5',64);
set local role service_role;
do $$ begin begin perform public.trustlane_public_booking_view(repeat('5',64)); raise exception 'Expired link allowed'; exception when raise_exception then if sqlerrm='Expired link allowed' then raise; end if; end; end $$;
set local role authenticated; select set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb',true);
do $$ begin
 if exists(select 1 from public.trustlane_signatures where lead_id='cccccccc-cccc-4ccc-cccc-cccccccccccc') then raise exception 'Other agent can see signatures'; end if;
 begin perform public.trustlane_issue_booking_link('cccccccc-cccc-4ccc-cccc-cccccccccccc',current_setting('test.quote')::uuid,repeat('4',64)); raise exception 'Other agent issued link'; exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$ begin
 if (select count(*) from public.trustlane_signatures where lead_id='cccccccc-cccc-4ccc-cccc-cccccccccccc')<>2 then raise exception 'Signature history incomplete'; end if;
 if (select count(*) from public.trustlane_orders where lead_id='cccccccc-cccc-4ccc-cccc-cccccccccccc')<>1 then raise exception 'Duplicate order'; end if;
 if not exists(select 1 from public.trustlane_quote_requests where id='cccccccc-cccc-4ccc-cccc-cccccccccccc' and contract_version=signed_contract_version) then raise exception 'Re-sign did not close agreement'; end if;
end $$;
rollback;
select 'booking agreement checks passed; test data rolled back' as result;
