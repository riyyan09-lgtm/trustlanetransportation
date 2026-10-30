-- Runs only after the manual-orders migration. All data is rolled back.
begin;
insert into auth.users(id,email) values
 ('aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa','test-order-a@example.invalid'),
 ('bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb','test-order-b@example.invalid');
insert into public.trustlane_profiles(user_id,display_name,role,active) values
 ('aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa','TEST ORDER A','agent',true),
 ('bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb','TEST ORDER B','agent',true);
insert into public.trustlane_quote_requests(id,request_id,name,email,phone,pickup,delivery,vehicle_year,vehicle_make,vehicle_model,preferred_date,assigned_to,quote_amount)
 values ('cccccccc-cccc-4ccc-cccc-cccccccccccc',gen_random_uuid(),'TEST ORDER','test@example.invalid','5555550100','Test pickup','Test delivery',2020,'Test','Vehicle',current_date,'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa',900);
set local role authenticated;
select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa',true);
create temp table order_test_ids(quote_id uuid,order_id uuid);
insert into order_test_ids(quote_id) select public.trustlane_create_quote_draft('cccccccc-cccc-4ccc-cccc-cccccccccccc');
do $$ begin
 begin perform public.trustlane_update_lead('cccccccc-cccc-4ccc-cccc-cccccccccccc','Booked',null,null,false); raise exception 'Book without order allowed';
 exception when raise_exception then if sqlerrm='Book without order allowed' then raise; end if; end;
 begin perform public.trustlane_record_manual_order('cccccccc-cccc-4ccc-cccc-cccccccccccc',(select quote_id from order_test_ids),'No confirmation',false); raise exception 'Order without confirmation allowed';
 exception when raise_exception then if sqlerrm='Order without confirmation allowed' then raise; end if; end;
end $$;
update order_test_ids set order_id=public.trustlane_record_manual_order('cccccccc-cccc-4ccc-cccc-cccccccccccc',quote_id,'TEST customer agreed',true);
do $$ begin
 if not exists(select 1 from public.trustlane_quote_requests where id='cccccccc-cccc-4ccc-cccc-cccccccccccc' and status='Booked') then raise exception 'Lead not booked after order'; end if;
 perform public.trustlane_update_order_stage((select order_id from order_test_ids),'Picked up');
 if not exists(select 1 from public.trustlane_orders where id=(select order_id from order_test_ids) and stage='Picked up') then raise exception 'Stage update failed'; end if;
 begin perform public.trustlane_record_manual_order('cccccccc-cccc-4ccc-cccc-cccccccccccc',(select quote_id from order_test_ids),'Duplicate test',true); raise exception 'Duplicate order allowed'; exception when unique_violation then null; end;
end $$;
select set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb',true);
do $$ begin
 if exists(select 1 from public.trustlane_orders where lead_id='cccccccc-cccc-4ccc-cccc-cccccccccccc') then raise exception 'Other agent can read order'; end if;
 begin perform public.trustlane_update_order_stage((select order_id from order_test_ids),'Delivered'); raise exception 'Other agent can update order'; exception when insufficient_privilege then null; end;
end $$;
rollback;
select 'manual order checks passed; test data rolled back' as result;
