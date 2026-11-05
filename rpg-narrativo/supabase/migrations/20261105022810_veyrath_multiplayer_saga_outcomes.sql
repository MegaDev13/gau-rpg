alter table veyrath_private.gm_arc_proposals
  drop constraint gm_arc_proposals_template_check,
  add constraint gm_arc_proposals_template_check check
    (template in ('apprentice','inheritance','ledger','council','flux','dragon','n01', 'n02', 'n03', 'n04', 'n05', 'n06'));
alter table veyrath_private.gm_arc_resolutions
  drop constraint gm_arc_resolutions_outcome_check,
  add constraint gm_arc_resolutions_outcome_check check
    (outcome in ('guild_licence','public_custody','supplier_cleared','route_charter','containment','habitat_protection','interim_council', 'household_mediation', 'civil_registry', 'river_cleanup', 'habitat_reserve', 'humanitarian_passage'));

-- Status authoritativo separado do save solo. A política permite leitura somente
-- para personagens inscritos no mundo, sem conceder escrita aos clientes.
create table public.veyrath_saga_settlement_state (
  world_id uuid not null,
  settlement_id uuid not null,
  saga text not null check (saga in ('n01', 'n02', 'n03', 'n04', 'n05', 'n06')),
  outcome text not null check (outcome in ('interim_council', 'household_mediation', 'civil_registry', 'river_cleanup', 'habitat_reserve', 'humanitarian_passage')),
  resolution_id uuid not null references veyrath_private.gm_arc_resolutions(id),
  starts_at timestamptz not null default now(),
  expires_at timestamptz,
  measure integer not null default 1 check (measure between 1 and 100),
  primary key (settlement_id,saga),
  foreign key (settlement_id,world_id) references public.veyrath_settlements(id,world_id),
  check (expires_at is null or expires_at > starts_at)
);
alter table public.veyrath_saga_settlement_state enable row level security;
revoke all on public.veyrath_saga_settlement_state from public, anon, authenticated, service_role;
grant select (world_id,settlement_id,saga,outcome,starts_at,expires_at,measure)
  on public.veyrath_saga_settlement_state to authenticated;
create index veyrath_saga_settlement_world_idx on public.veyrath_saga_settlement_state(world_id,settlement_id);
create index veyrath_saga_settlement_resolution_idx on public.veyrath_saga_settlement_state(resolution_id);
create policy veyrath_saga_state_members_read on public.veyrath_saga_settlement_state
 for select to authenticated using (
   world_id in (select c.world_id from public.veyrath_characters c where c.owner_id=(select auth.uid()))
 );


create or replace function veyrath_private.submit_arc_candidate(
  p_world_slug text, p_world_version bigint, p_template text, p_source_event uuid, p_actor uuid default null
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_world public.veyrath_worlds%rowtype;
  v_candidate veyrath_private.gm_arc_proposals%rowtype;
begin
  if p_template is null or p_template not in ('apprentice','inheritance','ledger','council','flux','dragon','n01', 'n02', 'n03', 'n04', 'n05', 'n06')
     or p_world_version is null or p_world_version < 0 then
    raise exception using errcode = '22023', message = 'Invalid chronicle template or world version';
  end if;
  select * into v_world from public.veyrath_worlds w where w.slug = p_world_slug for share;
  if not found then
    raise exception using errcode = '22023', message = 'Unknown world';
  end if;
  if not exists (
    select 1 from public.veyrath_gm_events e
    where e.id = p_source_event and e.world_id = v_world.id and e.visibility = 'public'
  ) then
    raise exception using errcode = '22023', message = 'Source must be a public event in the same world';
  end if;
  if p_actor is not null and not exists (
    select 1 from public.veyrath_characters c where c.id = p_actor and c.world_id = v_world.id
  ) then
    raise exception using errcode = '22023', message = 'Actor must belong to the same world';
  end if;

  select * into v_candidate from veyrath_private.gm_arc_proposals p
    where p.world_id = v_world.id and p.source_event_id = p_source_event and p.template = p_template;
  if not found then
    if v_world.version <> p_world_version then
      raise exception using errcode = '40001', message = 'World version changed; reconsider the proposal';
    end if;
    insert into veyrath_private.gm_arc_proposals (world_id, source_event_id, actor_id, world_version, template)
    values (v_world.id, p_source_event, p_actor, p_world_version, p_template)
    on conflict (world_id, source_event_id, template) do nothing
    returning * into v_candidate;
    if not found then
      select * into strict v_candidate from veyrath_private.gm_arc_proposals p
        where p.world_id = v_world.id and p.source_event_id = p_source_event and p.template = p_template;
    end if;
  end if;
  if v_candidate.actor_id is distinct from p_actor then
    raise exception using errcode = '22023', message = 'Existing proposal has a different actor';
  end if;
  return jsonb_build_object('id', v_candidate.id, 'status', v_candidate.status, 'template', v_candidate.template);
end
$$;

create or replace function veyrath_private.publish_arc_candidates(p_world uuid, p_limit integer default 20)
returns integer language plpgsql security invoker set search_path = '' as $$
declare
  v_version bigint;
  v_candidate veyrath_private.gm_arc_proposals%rowtype;
  v_status text;
  v_reason text;
  v_title text;
  v_count integer := 0;
begin
  if p_limit is null or p_limit not between 1 and 100 then
    raise exception using errcode = '22023', message = 'Invalid publication batch size';
  end if;
  select version into v_version from public.veyrath_worlds where id = p_world for update;
  if not found then
    return 0;
  end if;
  for v_candidate in
    select * from veyrath_private.gm_arc_proposals
    where world_id = p_world and status = 'scheduled' and scheduled_at <= now()
    order by scheduled_at, id limit p_limit for update skip locked
  loop
    v_status := 'rejected';
    v_reason := 'Missing public source or actor in this world';
    if v_candidate.world_version <> v_version then
      v_status := 'conflicted';
      v_reason := 'World version changed after proposal';
    elsif exists (
      select 1 from public.veyrath_gm_events e where e.id = v_candidate.source_event_id
        and e.world_id = p_world and e.visibility = 'public'
    ) and (v_candidate.actor_id is null or exists (
      select 1 from public.veyrath_characters c where c.id = v_candidate.actor_id and c.world_id = p_world
    )) then
      v_title := case v_candidate.template
        when 'apprentice' then 'O preço de uma assinatura'
        when 'inheritance' then 'A casa com duas chaves'
        when 'ledger' then 'A barca sem manifesto'
        when 'council' then 'As cartas da passagem'
        when 'flux' then 'As lentes do silêncio'
        when 'dragon' then 'Uma fronteira dracônica'
        when 'n01' then 'As cinzas da coroa adormecida'
        when 'n02' then 'A janela entre duas vidas'
        when 'n03' then 'A pele da cidade'
        when 'n04' then 'As águas que herdaram fogo'
        when 'n05' then 'O pacto do ninho silencioso'
        when 'n06' then 'A guerra que começou com um livro de pão'
      end;
      if v_title is not null then
        v_version := v_version + 1;
        update public.veyrath_worlds set version = v_version where id = p_world;
        insert into public.veyrath_chronicle_events (world_id, proposal_id, source_event_id, world_version, title)
          values (p_world, v_candidate.id, v_candidate.source_event_id, v_version, v_title);
        v_status := 'applied';
        v_reason := 'Public opening confirmed';
        v_count := v_count + 1;
      else
        v_reason := 'No publication handler for this template';
      end if;
    end if;
    update veyrath_private.gm_arc_proposals set status = v_status where id = v_candidate.id;
    insert into veyrath_private.gm_arc_audit (proposal_id, status, reason)
      values (v_candidate.id, v_status, v_reason);
  end loop;
  return v_count;
end
$$;

create or replace function veyrath_private.submit_arc_resolution(
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
   when 'n01' then 'interim_council'
   when 'n02' then 'household_mediation'
   when 'n03' then 'civil_registry'
   when 'n04' then 'river_cleanup'
   when 'n05' then 'habitat_reserve'
   when 'n06' then 'humanitarian_passage'
 end;
 if v_expected is null or p_outcome is distinct from v_expected then
   raise exception using errcode='22023',message='Outcome has no handler for this opening';
 end if;
 if not exists(select 1 from public.veyrath_gm_events where id=p_source and world_id=p_world and visibility='public')
    or not exists(select 1 from public.veyrath_settlements where id=p_target and world_id=p_world) then
   raise exception using errcode='22023',message='Source must be public and both source and target belong to this world';
 end if;
 if v_template like 'n0%' and not exists(
   select 1 from public.veyrath_gm_events e
   where e.id=p_source and e.settlement_id=p_target and e.kind='saga:'||v_template||':decision'
 ) then
   raise exception using errcode='22023',message='A saga resolution requires a decision event for the exact saga and settlement';
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

create or replace function veyrath_private.publish_arc_resolutions(p_world uuid,p_limit integer default 20)
returns integer language plpgsql security invoker set search_path='' as $$
declare
 v_world_version bigint;
 v_resolution veyrath_private.gm_arc_resolutions%rowtype;
 v_delta bigint;
 v_saga text;
 v_duration integer;
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
     select value.delta,value.title,value.summary,value.saga,value.duration into v_delta,v_title,v_description,v_saga,v_duration from (values
       ('guild_licence', 1, 'Ofício independente reconhecido', 'Uma licença registrada sustenta a produção local e acrescenta uma unidade à reserva.', null::text, null::integer),
       ('public_custody', -1, 'Acervo sob custódia pública', 'O acervo entra em guarda pública, com uma unidade de reserva comprometida para manutenção.', null::text, null::integer),
       ('supplier_cleared', 2, 'Fornecimento regularizado', 'O fornecedor autorizado repõe duas unidades da reserva pública.', null::text, null::integer),
       ('route_charter', 1, 'Passagem regularizada', 'A carta de passagem permite a entrega de uma unidade de provisões.', null::text, null::integer),
       ('containment', -2, 'Contenção aprovada', 'A contenção consome duas unidades das reservas do assentamento.', null::text, null::integer),
       ('habitat_protection', -1, 'Habitat protegido', 'A proteção do habitat reserva uma unidade para vigilância e mantém a autonomia dracônica.', null::text, null::integer),
       ('interim_council', -1, 'Conselho interino confirmado', 'O conselho assumiu a administração temporária. A sucessão continua aberta.', 'n01', 30),
       ('household_mediation', -1, 'Mediação familiar financiada', 'A cidade abriu atendimento voluntário para moradia e convivência. Nenhuma união foi registrada por terceiros.', 'n02', 30),
       ('civil_registry', -1, 'Registro civil aberto', 'O registro passou a aceitar pedidos individuais de reconhecimento civil.', 'n03', null),
       ('river_cleanup', -2, 'Recuperação do rio iniciada', 'Duas reservas financiaram a limpeza e a qualidade da água ganhou dez pontos.', 'n04', 60),
       ('habitat_reserve', -1, 'Reserva de habitat delimitada', 'O assentamento restringiu a exploração do entorno. A autonomia dracônica foi preservada.', 'n05', 90),
       ('humanitarian_passage', -2, 'Passagem humanitária aberta', 'A cidade reservou provisões para o corredor civil. O conflito ainda depende de um acordo entre as partes.', 'n06', 15)
     ) as value(outcome,delta,title,summary,saga,duration) where value.outcome=v_resolution.outcome;
     if found then
       if v_saga is not null and not exists(
         select 1 from public.veyrath_gm_events e where e.id=v_resolution.source_id
           and e.settlement_id=v_resolution.target_id and e.kind='saga:'||v_saga||':decision'
       ) then
         update veyrath_private.gm_arc_resolutions set status='rejected' where id=v_resolution.id;
         insert into veyrath_private.gm_arc_resolution_audit(resolution_id,status,reason)
           values(v_resolution.id,'rejected','Saga decision was withdrawn or no longer matches');
         continue;
       end if;
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
         if v_saga is not null then
           insert into public.veyrath_saga_settlement_state as state
             (world_id,settlement_id,saga,outcome,resolution_id,expires_at,measure)
             values (p_world,v_resolution.target_id,v_saga,v_resolution.outcome,v_resolution.id,
               CASE WHEN v_duration IS NOT NULL THEN now()+make_interval(days=>v_duration) END,case when v_saga='n04' then 10 else 1 end)
           on conflict(settlement_id,saga) do update
             set outcome=excluded.outcome,resolution_id=excluded.resolution_id,starts_at=excluded.starts_at,
               expires_at=excluded.expires_at,measure=case when v_saga='n04' then least(100,state.measure+10) else 1 end;
         end if;
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
