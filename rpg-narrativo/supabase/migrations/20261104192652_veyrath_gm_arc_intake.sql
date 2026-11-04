create table veyrath_private.gm_arc_proposals (
  id uuid primary key default gen_random_uuid(),
  world_id uuid not null references public.veyrath_worlds(id) on delete cascade,
  source_event_id uuid not null references public.veyrath_gm_events(id) on delete cascade,
  actor_id uuid references public.veyrath_characters(id) on delete set null,
  world_version bigint not null check (world_version >= 0),
  template text not null check (template in ('apprentice','inheritance','ledger','council','flux','dragon')),
  status text not null default 'pending' check (status = 'pending'),
  proposed_at timestamptz not null default now(),
  unique (world_id, source_event_id, template)
);

alter table veyrath_private.gm_arc_proposals enable row level security;
revoke all on table veyrath_private.gm_arc_proposals from public, anon, authenticated, service_role;
create index gm_arc_proposals_source_idx on veyrath_private.gm_arc_proposals(source_event_id);
create index gm_arc_proposals_actor_idx on veyrath_private.gm_arc_proposals(actor_id) where actor_id is not null;

-- Intentionally callable by the privileged scheduler's SQL connector only.
-- This records a proposal. It does not apply a narrative outcome or any effect.
create function veyrath_private.submit_arc_candidate(
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
  if p_template is null or p_template not in ('apprentice','inheritance','ledger','council','flux','dragon')
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

revoke all on function veyrath_private.submit_arc_candidate(text,bigint,text,uuid,uuid)
  from public, anon, authenticated, service_role;
