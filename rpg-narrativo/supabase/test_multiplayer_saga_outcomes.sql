begin;
do $test$
declare
 saga text;
 outcome text;
 w uuid;
 slug text;
 city uuid;
 other_city uuid;
 cycle uuid;
 opening_source uuid;
 outcome_source uuid;
 opening uuid;
 resolution uuid;
 expected_supplies bigint;
begin
 foreach saga in array array['n01','n02','n03','n04','n05','n06'] loop
  outcome := case saga when 'n01' then 'interim_council' when 'n02' then 'household_mediation'
    when 'n03' then 'civil_registry' when 'n04' then 'river_cleanup'
    when 'n05' then 'habitat_reserve' when 'n06' then 'humanitarian_passage' end;
  expected_supplies := case when saga in ('n04','n06') then 8 else 9 end;
  slug := 'qa-saga-'||saga||'-'||gen_random_uuid();
  insert into public.veyrath_worlds(slug,name) values(slug,'Isolated saga QA') returning id into w;
  insert into public.veyrath_settlements(world_id,name,region) values(w,'Target','test') returning id into city;
  insert into public.veyrath_settlements(world_id,name,region) values(w,'Wrong target','test') returning id into other_city;
  insert into public.veyrath_gm_cycles(world_id,cycle_hour,observed_world_version,summary)
    values(w,date_trunc('hour',now()),0,'Isolated QA') returning id into cycle;
  insert into public.veyrath_gm_events(cycle_id,world_id,settlement_id,scope,kind,title,narrative,event_order)
    values(cycle,w,city,'local','saga:opening','Opening cause','Isolated evidence',1) returning id into opening_source;
  insert into public.veyrath_gm_events(cycle_id,world_id,settlement_id,scope,kind,title,narrative,event_order)
    values(cycle,w,city,'local','saga:'||saga||':decision','Decision','Isolated evidence',2) returning id into outcome_source;
  opening := (veyrath_private.submit_arc_candidate(slug,0,saga,opening_source)->>'id')::uuid;
  perform veyrath_private.review_arc_candidate(opening,true);
  if veyrath_private.publish_arc_candidates(w)<>1 then raise exception 'Opening missing for %',saga; end if;
  begin
    perform veyrath_private.submit_arc_resolution(w,1,opening,outcome_source,other_city,outcome);
    raise exception 'Wrong settlement accepted';
  exception when invalid_parameter_value then null; end;
  begin
    perform veyrath_private.submit_arc_resolution(w,1,opening,opening_source,city,outcome);
    raise exception 'Non-decision event accepted';
  exception when invalid_parameter_value then null; end;
  resolution := veyrath_private.submit_arc_resolution(w,1,opening,outcome_source,city,outcome);
  if veyrath_private.publish_arc_resolutions(w)<>0 then raise exception 'Pending saga applied'; end if;
  perform veyrath_private.review_arc_resolution(resolution,true);
  if veyrath_private.publish_arc_resolutions(w)<>1 then raise exception 'Resolution missing for %',saga; end if;
  if veyrath_private.publish_arc_resolutions(w)<>0 then raise exception 'Resolution duplicated for %',saga; end if;
  if (select public_supplies from public.veyrath_settlements where id=city)<>expected_supplies
    or (select count(*) from public.veyrath_chronicle_events e where e.world_id=w and e.kind='resolution')<>1
    or not exists(select 1 from public.veyrath_saga_settlement_state s where s.resolution_id=resolution
      and s.world_id=w and s.settlement_id=city and s.measure=case when s.saga='n04' then 10 else 1 end) then
    raise exception 'Incorrect saga consequence for %',saga;
  end if;
 end loop;
 if has_table_privilege('authenticated','public.veyrath_saga_settlement_state','insert')
   or has_column_privilege('anon','public.veyrath_saga_settlement_state','outcome','select')
   or has_column_privilege('authenticated','public.veyrath_saga_settlement_state','resolution_id','select') then
   raise exception 'Unexpected game client privileges';
 end if;
end
$test$;
rollback;
select 'N01-N06: reviewed opening, exact cause and target, reserves, state, feed, idempotence and ACL' as test;
