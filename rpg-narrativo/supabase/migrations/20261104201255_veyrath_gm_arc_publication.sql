alter table veyrath_private.gm_arc_proposals
  drop constraint gm_arc_proposals_status_check,
  add column scheduled_at timestamptz,
  add constraint gm_arc_proposals_status_check
    check (status in ('pending', 'scheduled', 'applied', 'rejected', 'conflicted'));

create index gm_arc_proposals_schedule_idx
  on veyrath_private.gm_arc_proposals (world_id, scheduled_at, id) where status = 'scheduled';

create table veyrath_private.gm_arc_audit (
  id bigint generated always as identity primary key,
  proposal_id uuid not null references veyrath_private.gm_arc_proposals(id),
  status text not null check (status in ('scheduled', 'applied', 'rejected', 'conflicted')),
  reason text not null,
  recorded_at timestamptz not null default now(),
  unique (proposal_id, status)
);
alter table veyrath_private.gm_arc_audit enable row level security;
revoke all on table veyrath_private.gm_arc_audit from public, anon, authenticated, service_role;

create table public.veyrath_chronicle_events (
  seq bigint generated always as identity primary key,
  world_id uuid not null references public.veyrath_worlds(id),
  proposal_id uuid not null unique references veyrath_private.gm_arc_proposals(id),
  source_event_id uuid not null references public.veyrath_gm_events(id),
  world_version bigint not null,
  title text not null,
  published_at timestamptz not null default now()
);
alter table public.veyrath_chronicle_events enable row level security;
revoke all on table public.veyrath_chronicle_events from public, anon, authenticated, service_role;
grant select (seq, world_id, source_event_id, world_version, title, published_at)
  on public.veyrath_chronicle_events to authenticated;
create index veyrath_chronicle_events_cursor_idx on public.veyrath_chronicle_events (world_id, seq);
create index veyrath_chronicle_events_source_idx on public.veyrath_chronicle_events (source_event_id);

create policy veyrath_chronicle_members_read on public.veyrath_chronicle_events
for select to authenticated using (
  world_id in (select c.world_id from public.veyrath_characters c where c.owner_id = (select auth.uid()))
);

-- Trusted review is required. Existing pending proposals never self-approve.
create function veyrath_private.review_arc_candidate(p_id uuid, p_approve boolean, p_at timestamptz default now())
returns boolean language plpgsql security invoker set search_path = '' as $$
declare
  v_status text;
begin
  if p_approve is null or (p_approve and p_at is null) then
    raise exception using errcode = '22023', message = 'Review requires a decision and publication time';
  end if;
  update veyrath_private.gm_arc_proposals
    set status = case when p_approve then 'scheduled' else 'rejected' end,
        scheduled_at = case when p_approve then greatest(p_at, now()) else null end
    where id = p_id and status = 'pending'
    returning status into v_status;
  if not found then
    return false;
  end if;
  insert into veyrath_private.gm_arc_audit (proposal_id, status, reason)
    values (p_id, v_status, 'Operator review');
  return true;
end
$$;

-- One world lock orders all publications, including cursor allocation. Lock and audit
-- are in the same transaction. The only registered effect is publishing an opening.
create function veyrath_private.publish_arc_candidates(p_world uuid, p_limit integer default 20)
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

revoke all on function veyrath_private.review_arc_candidate(uuid,boolean,timestamptz)
  from public, anon, authenticated, service_role;
revoke all on function veyrath_private.publish_arc_candidates(uuid,integer)
  from public, anon, authenticated, service_role;
