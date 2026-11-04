begin;
do $verify$
declare
 w public.veyrath_worlds%rowtype;
 source_id uuid;
 proposal jsonb;
 repeated jsonb;
begin
 insert into public.veyrath_worlds (slug,name,year_pr,version)
 values ('test-gm-arc-'||gen_random_uuid(),'Isolated GM intake test',312,0) returning * into w;
 with cycle as (
   insert into public.veyrath_gm_cycles(world_id,cycle_hour,observed_world_version,summary)
   values (w.id,date_trunc('hour',now()),0,'Isolated test cycle') returning id
 )
 insert into public.veyrath_gm_events(cycle_id,world_id,scope,kind,title,narrative)
 select id,w.id,'local','test','Isolated test event','Public evidence for a rolled back test' from cycle
 returning id into source_id;
 if has_function_privilege('authenticated','veyrath_private.submit_arc_candidate(text,bigint,text,uuid,uuid)','execute')
    or has_function_privilege('anon','veyrath_private.submit_arc_candidate(text,bigint,text,uuid,uuid)','execute')
    or has_table_privilege('authenticated','veyrath_private.gm_arc_proposals','insert') then
   raise exception 'Unexpected player access';
 end if;
 begin
  perform veyrath_private.submit_arc_candidate(w.slug,w.version+1,'apprentice',source_id);
  raise exception 'Expected stale version rejection';
 exception when serialization_failure then null;
 end;
 begin
  perform veyrath_private.submit_arc_candidate(w.slug,w.version,'inventar_poder',source_id);
  raise exception 'Expected invalid template rejection';
 exception when invalid_parameter_value then null;
 end;
 begin
  perform veyrath_private.submit_arc_candidate(w.slug,w.version,'flux',gen_random_uuid());
  raise exception 'Expected unknown source rejection';
 exception when invalid_parameter_value then null;
 end;
 proposal := veyrath_private.submit_arc_candidate(w.slug,w.version,'apprentice',source_id);
 repeated := veyrath_private.submit_arc_candidate(w.slug,w.version,'apprentice',source_id);
 if proposal->>'status'<>'pending' or proposal->>'id' is distinct from repeated->>'id' then
   raise exception 'Proposal not pending or not idempotent';
 end if;
 if (select version from public.veyrath_worlds where id=w.id) <> w.version then
   raise exception 'Proposal changed world';
 end if;
end
$verify$;
rollback;
select 'intake: validation, privileges, idempotence, rollback' as test;
