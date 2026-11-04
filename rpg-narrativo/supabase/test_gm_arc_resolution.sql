begin;
do $test$
declare
 w uuid;
 other_world uuid;
 target uuid;
 other_target uuid;
 source uuid;
 secret_source uuid;
 cycle uuid;
 opening uuid;
 resolution uuid;
begin
 insert into public.veyrath_worlds(slug,name) values('v13-rollback-'||gen_random_uuid(),'Isolated rollback') returning id into w;
 insert into public.veyrath_worlds(slug,name) values('v13-other-'||gen_random_uuid(),'Isolated other world') returning id into other_world;
 insert into public.veyrath_settlements(world_id,name,region,public_supplies) values(w,'Target','test',10) returning id into target;
 insert into public.veyrath_settlements(world_id,name,region,public_supplies) values(other_world,'Other','test',10) returning id into other_target;
 insert into public.veyrath_gm_cycles(world_id,cycle_hour,observed_world_version,summary)
  values(w,date_trunc('hour',now()),0,'Isolated test') returning id into cycle;
 insert into public.veyrath_gm_events(cycle_id,world_id,scope,kind,title,narrative)
  values(cycle,w,'local','test','Fixture','Fixture') returning id into source;
 insert into public.veyrath_gm_events(cycle_id,world_id,scope,kind,title,narrative,event_order,visibility)
  values(cycle,w,'local','test','Secret fixture','Secret fixture',2,'secret') returning id into secret_source;
 opening := (veyrath_private.submit_arc_candidate((select slug from public.veyrath_worlds where id=w),0,'ledger',source)->>'id')::uuid;
 perform veyrath_private.review_arc_candidate(opening,true);
 if veyrath_private.publish_arc_candidates(w)<>1 then raise exception 'Opening was not applied'; end if;
 begin
   perform veyrath_private.submit_arc_resolution(w,1,opening,source,other_target,'supplier_cleared');
   raise exception 'Wrong-world target accepted';
 exception when invalid_parameter_value then null; end;
 begin
   perform veyrath_private.submit_arc_resolution(w,1,opening,secret_source,target,'supplier_cleared');
   raise exception 'Secret source accepted';
 exception when invalid_parameter_value then null; end;
 begin
   perform veyrath_private.submit_arc_resolution(w,1,opening,source,target,'containment');
   raise exception 'Wrong operation accepted';
 exception when invalid_parameter_value then null; end;
 begin
   perform veyrath_private.submit_arc_resolution(w,0,opening,source,target,'supplier_cleared');
   raise exception 'Stale version accepted';
 exception when serialization_failure then null; end;
 resolution := veyrath_private.submit_arc_resolution(w,1,opening,source,target,'supplier_cleared');
 if resolution is distinct from veyrath_private.submit_arc_resolution(w,1,opening,source,target,'supplier_cleared')
   or veyrath_private.publish_arc_resolutions(w)<>0 then raise exception 'Pending or duplicate applied'; end if;
 if has_function_privilege('authenticated','veyrath_private.publish_arc_resolutions(uuid,integer)','execute')
   or has_function_privilege('authenticated','veyrath_private.submit_arc_resolution(uuid,bigint,uuid,uuid,uuid,text)','execute')
   or has_table_privilege('anon','veyrath_private.world_arc_effects','select') then raise exception 'Unexpected player privilege'; end if;
 perform veyrath_private.review_arc_resolution(resolution,true);
 begin
   if veyrath_private.publish_arc_resolutions(w)<>1 then raise exception 'Resolution missing'; end if;
   raise exception using errcode='P0420',message='force rollback after publication';
 exception when sqlstate 'P0420' then null; end;
 if (select public_supplies from public.veyrath_settlements where id=target)<>10
   or exists(select 1 from public.veyrath_chronicle_events where world_id=w and kind='resolution') then
   raise exception 'Partial write escaped rollback';
 end if;
 if veyrath_private.publish_arc_resolutions(w)<>1 or veyrath_private.publish_arc_resolutions(w)<>0 then
   raise exception 'Expected exactly one application';
 end if;
 if (select public_supplies from public.veyrath_settlements where id=target)<>12
   or (select version from public.veyrath_worlds where id=w)<>2
   or (select count(*) from public.veyrath_chronicle_events where world_id=w)<>2
   or not exists(select 1 from veyrath_private.world_arc_effects e where e.resolution_id=resolution and e.supply_delta=2) then
   raise exception 'Expected one effect, audit, version and resolution publication';
 end if;
end
$test$;
rollback;
select 'resolution: pending, typed validation, rollback, feed and public reserves' as test;
