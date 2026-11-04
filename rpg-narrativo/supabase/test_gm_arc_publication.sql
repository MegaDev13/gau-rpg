begin;
do $verify$
declare
 w public.veyrath_worlds%rowtype;
 other_world public.veyrath_worlds%rowtype;
 source_id uuid;
 secret_id uuid;
 first uuid;
 stale uuid;
 cycle_id uuid;
begin
 insert into public.veyrath_worlds(slug,name,year_pr,version)
 values ('test-arc-publication-'||gen_random_uuid(),'Isolated publication test',312,0) returning * into w;
 insert into public.veyrath_worlds(slug,name,year_pr,version)
 values ('test-arc-other-'||gen_random_uuid(),'Isolated other world',312,0) returning * into other_world;
 insert into public.veyrath_gm_cycles(world_id,cycle_hour,observed_world_version,summary)
 values (w.id,date_trunc('hour',now()),0,'Isolated test cycle') returning id into cycle_id;
 insert into public.veyrath_gm_events(cycle_id,world_id,scope,kind,title,narrative)
 values (cycle_id,w.id,'local','test','Fixture pública','Sem efeito no mundo real') returning id into source_id;
 insert into public.veyrath_gm_events(cycle_id,world_id,scope,kind,title,narrative,visibility,event_order)
 values (cycle_id,w.id,'local','test','Fixture secreta','Sem efeito no mundo real','secret',2) returning id into secret_id;
 if has_function_privilege('authenticated','veyrath_private.review_arc_candidate(uuid,boolean,timestamptz)','execute')
    or has_function_privilege('authenticated','veyrath_private.publish_arc_candidates(uuid,integer)','execute')
    or has_table_privilege('authenticated','public.veyrath_chronicle_events','insert')
    or has_column_privilege('anon','public.veyrath_chronicle_events','seq','select') then
   raise exception 'Unexpected player/anon privilege';
 end if;
 begin
  perform veyrath_private.submit_arc_candidate(other_world.slug,0,'dragon',source_id);
  raise exception 'Accepted other-world source';
 exception when invalid_parameter_value then null;
 end;
 begin
  perform veyrath_private.submit_arc_candidate(w.slug,0,'dragon',secret_id);
  raise exception 'Accepted secret source';
 exception when invalid_parameter_value then null;
 end;
 first := (veyrath_private.submit_arc_candidate(w.slug,0,'apprentice',source_id)->>'id')::uuid;
 stale := (veyrath_private.submit_arc_candidate(w.slug,0,'flux',source_id)->>'id')::uuid;
 if veyrath_private.publish_arc_candidates(w.id) <> 0 then
   raise exception 'Pending proposal applied';
 end if;
 if not veyrath_private.review_arc_candidate(first,true) or veyrath_private.review_arc_candidate(first,true) then
   raise exception 'Trusted review is not idempotent';
 end if;
 begin
   if veyrath_private.publish_arc_candidates(w.id) <> 1 then
     raise exception 'Fixture did not publish';
   end if;
   raise exception using errcode='P0420',message='Intentional rollback after writing';
 exception when sqlstate 'P0420' then null;
 end;
 if exists(select 1 from public.veyrath_chronicle_events e where e.world_id=w.id)
    or (select version from public.veyrath_worlds where id=w.id) <> 0
    or (select status from veyrath_private.gm_arc_proposals where id=first) <> 'scheduled' then
   raise exception 'Partial effect survived rollback';
 end if;
 if veyrath_private.publish_arc_candidates(w.id) <> 1 then raise exception 'Expected one publication'; end if;
 if veyrath_private.publish_arc_candidates(w.id) <> 0 then raise exception 'Publication repeated'; end if;
 if not veyrath_private.review_arc_candidate(stale,true) then raise exception 'Stale fixture could not be queued'; end if;
 if veyrath_private.publish_arc_candidates(w.id) <> 0 then raise exception 'Stale proposal published'; end if;
 if (select count(*) from public.veyrath_chronicle_events e where e.world_id=w.id) <> 1
    or (select version from public.veyrath_worlds where id=w.id) <> 1
    or (select status from veyrath_private.gm_arc_proposals where id=stale) <> 'conflicted'
    or not exists(select 1 from veyrath_private.gm_arc_audit a where a.proposal_id=first and a.status='applied') then
   raise exception 'Unexpected status, version, audit, or feed';
 end if;
 perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
 execute 'set local role authenticated';
 if exists(select seq from public.veyrath_chronicle_events e where e.world_id=w.id) then
   raise exception 'RLS leaked a different world';
 end if;
 execute 'reset role';
end
$verify$;
rollback;
select 'publication: review, rollback, replay, stale proposals, sources, and RLS' as test;
