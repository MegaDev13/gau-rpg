alter table public.veyrath_chronicle_events
  add column kind text not null default 'opening' check (kind in ('opening','resolution')),
  add column description text,
  drop constraint veyrath_chronicle_events_proposal_id_key,
  add constraint veyrath_chronicle_event_kind_key unique (proposal_id, kind);
grant select (kind, description) on public.veyrath_chronicle_events to authenticated;

create table veyrath_private.gm_arc_resolutions (
  id uuid primary key default gen_random_uuid(),
  proposal_id uuid not null unique references veyrath_private.gm_arc_proposals(id),
  world_id uuid not null references public.veyrath_worlds(id),
  world_version bigint not null check (world_version >= 0),
  source_id uuid not null references public.veyrath_gm_events(id),
  target_id uuid not null references public.veyrath_settlements(id),
  outcome text not null check (outcome in ('guild_licence','public_custody','supplier_cleared','route_charter','containment','habitat_protection')),
  status text not null default 'pending' check (status in ('pending','scheduled','applied','rejected','conflicted')),
  scheduled_at timestamptz,
  created_at timestamptz not null default now()
);
alter table veyrath_private.gm_arc_resolutions enable row level security;
revoke all on veyrath_private.gm_arc_resolutions from public, anon, authenticated, service_role;
create index gm_arc_resolutions_queue_idx on veyrath_private.gm_arc_resolutions(world_id,scheduled_at,id) where status='scheduled';
create index gm_arc_resolutions_source_idx on veyrath_private.gm_arc_resolutions(source_id);
create index gm_arc_resolutions_target_idx on veyrath_private.gm_arc_resolutions(target_id);

create table veyrath_private.gm_arc_resolution_audit (
  id bigint generated always as identity primary key,
  resolution_id uuid not null references veyrath_private.gm_arc_resolutions(id),
  status text not null,
  reason text not null,
  reviewer text not null default current_user,
  at timestamptz not null default now(),
  unique (resolution_id,status)
);
alter table veyrath_private.gm_arc_resolution_audit enable row level security;
revoke all on veyrath_private.gm_arc_resolution_audit from public, anon, authenticated, service_role;

create table veyrath_private.world_arc_effects (
  resolution_id uuid primary key references veyrath_private.gm_arc_resolutions(id),
  world_id uuid not null references public.veyrath_worlds(id),
  settlement_id uuid not null references public.veyrath_settlements(id),
  effect text not null,
  supply_delta bigint not null,
  applied_at timestamptz not null default now()
);
alter table veyrath_private.world_arc_effects enable row level security;
revoke all on veyrath_private.world_arc_effects from public, anon, authenticated, service_role;
create index world_arc_effects_world_idx on veyrath_private.world_arc_effects(world_id);
create index world_arc_effects_settlement_idx on veyrath_private.world_arc_effects(settlement_id);

-- Callers submit one typed outcome. Amounts, public summaries and permissions are
-- server-owned. The legacy proposal must already have a confirmed opening.
create function veyrath_private.submit_arc_resolution(
 p_world uuid,p_version bigint,p_proposal uuid,p_source uuid,p_target uuid,p_outcome text
) returns uuid language plpgsql security invoker set search_path='' as $$
declare
 v_version bigint;
 v_template text;
 v_expected text;
 v_prior veyrath_private.gm_arc_resolutions%rowtype;
 v_id uuid;
begin
 select version into v_version from public.veyrath_worlds where id=p_world for share;
 if not found then raise exception using errcode='22023',message='Unknown world'; end if;
 select template into v_template from veyrath_private.gm_arc_proposals
   where id=p_proposal and world_id=p_world and status='applied';
 v_expected := case v_template
   when 'apprentice' then 'guild_licence'
   when 'inheritance' then 'public_custody'
   when 'ledger' then 'supplier_cleared'
   when 'council' then 'route_charter'
   when 'flux' then 'containment'
   when 'dragon' then 'habitat_protection'
 end;
 if v_expected is null or p_outcome is distinct from v_expected then
   raise exception using errcode='22023',message='Outcome has no handler for this opening';
 end if;
 if not exists(select 1 from public.veyrath_gm_events where id=p_source and world_id=p_world and visibility='public')
    or not exists(select 1 from public.veyrath_settlements where id=p_target and world_id=p_world) then
   raise exception using errcode='22023',message='Source must be public and both source and target belong to this world';
 end if;
 select * into v_prior from veyrath_private.gm_arc_resolutions where proposal_id=p_proposal;
 if found then
   if (v_prior.source_id,v_prior.target_id,v_prior.outcome,v_prior.world_version) is distinct from (p_source,p_target,p_outcome,p_version) then
     raise exception using errcode='22023',message='Opening already has a different proposed resolution';
   end if;
   return v_prior.id;
 end if;
 if v_version is distinct from p_version then raise exception using errcode='40001',message='World version changed'; end if;
 insert into veyrath_private.gm_arc_resolutions(proposal_id,world_id,world_version,source_id,target_id,outcome)
   values(p_proposal,p_world,p_version,p_source,p_target,p_outcome)
   on conflict(proposal_id) do nothing returning id into v_id;
 if v_id is null then
   select * into strict v_prior from veyrath_private.gm_arc_resolutions where proposal_id=p_proposal;
   if (v_prior.source_id,v_prior.target_id,v_prior.outcome,v_prior.world_version) is distinct from (p_source,p_target,p_outcome,p_version) then
     raise exception using errcode='22023',message='Opening already has a different proposed resolution';
   end if;
   return v_prior.id;
 end if;
 return v_id;
end
$$;

create function veyrath_private.review_arc_resolution(p_id uuid,p_approve boolean,p_at timestamptz default now())
returns boolean language plpgsql security invoker set search_path='' as $$
declare v_status text;
begin
 if p_approve is null or (p_approve and p_at is null) then
   raise exception using errcode='22023',message='Missing review or schedule';
 end if;
 update veyrath_private.gm_arc_resolutions set status=case when p_approve then 'scheduled' else 'rejected' end,
   scheduled_at=case when p_approve then greatest(now(),p_at) end
   where id=p_id and status='pending' returning status into v_status;
 if not found then return false; end if;
 insert into veyrath_private.gm_arc_resolution_audit(resolution_id,status,reason)
   values(p_id,v_status,'Explicit operator review');
 return true;
end
$$;

create function veyrath_private.publish_arc_resolutions(p_world uuid,p_limit integer default 20)
returns integer language plpgsql security invoker set search_path='' as $$
declare
 v_world_version bigint;
 v_resolution veyrath_private.gm_arc_resolutions%rowtype;
 v_delta bigint;
 v_title text;
 v_description text;
 v_status text;
 v_reason text;
 v_applied integer := 0;
begin
 if p_limit is null or p_limit not between 1 and 100 then raise exception using errcode='22023',message='Invalid batch'; end if;
 select version into v_world_version from public.veyrath_worlds where id=p_world for update;
 if not found then return 0; end if;
 for v_resolution in select * from veyrath_private.gm_arc_resolutions where world_id=p_world
   and status='scheduled' and scheduled_at<=now() order by scheduled_at,id limit p_limit for update skip locked
 loop
   v_status := 'rejected';
   v_reason := 'Public cause or confirmed opening no longer valid';
   if v_world_version <> v_resolution.world_version then
     v_status := 'conflicted';
     v_reason := 'World version changed after review';
   elsif exists(select 1 from public.veyrath_gm_events e where e.id=v_resolution.source_id and e.world_id=p_world and e.visibility='public')
     and exists(select 1 from public.veyrath_chronicle_events e where e.proposal_id=v_resolution.proposal_id and e.world_id=p_world and e.kind='opening') then
     select value.delta,value.title,value.summary into v_delta,v_title,v_description from (values
       ('guild_licence', 1, 'Ofício independente reconhecido', 'Uma licença registrada sustenta a produção local e acrescenta uma unidade à reserva.'),
       ('public_custody', -1, 'Acervo sob custódia pública', 'O acervo entra em guarda pública, com uma unidade de reserva comprometida para manutenção.'),
       ('supplier_cleared', 2, 'Fornecimento regularizado', 'O fornecedor autorizado repõe duas unidades da reserva pública.'),
       ('route_charter', 1, 'Passagem regularizada', 'A carta de passagem permite a entrega de uma unidade de provisões.'),
       ('containment', -2, 'Contenção aprovada', 'A contenção consome duas unidades das reservas do assentamento.'),
       ('habitat_protection', -1, 'Habitat protegido', 'A proteção do habitat reserva uma unidade para vigilância e mantém a autonomia dracônica.')
     ) as value(outcome,delta,title,summary) where value.outcome=v_resolution.outcome;
     if found then
       -- Contributions may already hold the settlement row and be waiting for this world.
       -- Keep the candidate scheduled instead of waiting in reverse lock order.
       begin
         perform 1 from public.veyrath_settlements where id=v_resolution.target_id and world_id=p_world for update nowait;
       exception when lock_not_available then
         continue;
       end;
       update public.veyrath_settlements set public_supplies=public_supplies+v_delta,version=version+1
         where id=v_resolution.target_id and world_id=p_world and public_supplies+v_delta>=0;
       if found then
         v_world_version := v_world_version+1;
         update public.veyrath_worlds set version=v_world_version where id=p_world;
         insert into veyrath_private.world_arc_effects(resolution_id,world_id,settlement_id,effect,supply_delta)
           values(v_resolution.id,p_world,v_resolution.target_id,v_resolution.outcome,v_delta);
         insert into public.veyrath_chronicle_events(world_id,proposal_id,source_event_id,world_version,kind,title,description)
           values(p_world,v_resolution.proposal_id,v_resolution.source_id,v_world_version,'resolution',v_title,v_description);
         v_applied := v_applied+1;
         v_status := 'applied';
         v_reason := 'Typed outcome and public settlement delta committed';
       else
         v_reason := 'Settlement missing or public reserves insufficient';
       end if;
     end if;
   end if;
   update veyrath_private.gm_arc_resolutions set status=v_status where id=v_resolution.id;
   insert into veyrath_private.gm_arc_resolution_audit(resolution_id,status,reason)
     values(v_resolution.id,v_status,v_reason);
 end loop;
 return v_applied;
end
$$;
revoke all on function veyrath_private.submit_arc_resolution(uuid,bigint,uuid,uuid,uuid,text),
  veyrath_private.review_arc_resolution(uuid,boolean,timestamptz),
  veyrath_private.publish_arc_resolutions(uuid,integer) from public, anon, authenticated, service_role;

-- Replace the command of the existing publisher. The hourly Master remains independent.
select cron.schedule('veyrath-arc-publication','10 * * * *',$job$
  select case when exists(select 1 from veyrath_private.gm_arc_resolutions r
                 where r.world_id=w.id and r.status='scheduled' and r.scheduled_at<=now())
              then veyrath_private.publish_arc_resolutions(w.id)
              else veyrath_private.publish_arc_candidates(w.id) end
  from public.veyrath_worlds w
  where exists(select 1 from veyrath_private.gm_arc_resolutions r
             where r.world_id=w.id and r.status='scheduled' and r.scheduled_at<=now())
     or exists(select 1 from veyrath_private.gm_arc_proposals p
             where p.world_id=w.id and p.status='scheduled' and p.scheduled_at<=now())
  order by w.id
$job$);
