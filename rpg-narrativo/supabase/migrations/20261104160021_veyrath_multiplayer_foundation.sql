-- Veyrath multiplayer foundation. No client can update authoritative resources directly.
create schema if not exists veyrath_private;
revoke all on schema veyrath_private from public, anon, authenticated;
grant usage on schema veyrath_private to authenticated;

create table public.veyrath_worlds (
 id uuid primary key default gen_random_uuid(),
 slug text not null unique,
 name text not null,
 year_pr integer not null default 312 check (year_pr >= 0),
 version bigint not null default 0 check (version >= 0)
);
create table public.veyrath_settlements (
 id uuid primary key default gen_random_uuid(),
 world_id uuid not null references public.veyrath_worlds(id),
 name text not null,
 region text not null,
 public_supplies bigint not null default 10 check (public_supplies >= 0),
 version bigint not null default 0 check (version >= 0),
 unique (world_id, name), unique (id, world_id)
);
create table public.veyrath_characters (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id),
 world_id uuid not null references public.veyrath_worlds(id),
 name text not null check (char_length(name) between 1 and 40),
 credits bigint not null default 5 check (credits >= 0),
 version bigint not null default 0 check (version >= 0),
 created_at timestamptz not null default now(),
 unique (owner_id, world_id), unique (id, world_id)
);
create table public.veyrath_commands (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id),
 actor_id uuid not null,
 world_id uuid not null,
 settlement_id uuid not null,
 idempotency_key uuid not null,
 kind text not null check (kind in ('contribute_supplies')),
 status text not null default 'pending' check (status in ('pending','applied','rejected')),
 created_at timestamptz not null default now(),
 available_at timestamptz not null,
 processed_at timestamptz,
 rejection_reason text,
 unique(owner_id, idempotency_key),
 foreign key(actor_id, world_id) references public.veyrath_characters(id, world_id),
 foreign key(settlement_id, world_id) references public.veyrath_settlements(id, world_id)
);
create table public.veyrath_events (
 id uuid primary key default gen_random_uuid(),
 world_id uuid not null references public.veyrath_worlds(id),
 settlement_id uuid not null,
 command_id uuid not null unique references public.veyrath_commands(id),
 kind text not null,
 description text not null,
 world_version bigint not null,
 created_at timestamptz not null default now(),
 unique(world_id, world_version),
 foreign key(settlement_id,world_id) references public.veyrath_settlements(id,world_id)
);
create index veyrath_commands_due on public.veyrath_commands(available_at, created_at, id) where status='pending';
create index veyrath_commands_owner on public.veyrath_commands(owner_id, created_at desc);
create index veyrath_events_world on public.veyrath_events(world_id, world_version desc);

alter table public.veyrath_worlds enable row level security;
alter table public.veyrath_settlements enable row level security;
alter table public.veyrath_characters enable row level security;
alter table public.veyrath_commands enable row level security;
alter table public.veyrath_events enable row level security;
revoke all on public.veyrath_worlds, public.veyrath_settlements, public.veyrath_characters, public.veyrath_commands, public.veyrath_events from public, anon, authenticated;
grant select on public.veyrath_worlds, public.veyrath_settlements, public.veyrath_characters, public.veyrath_commands, public.veyrath_events to authenticated;
create policy worlds_read on public.veyrath_worlds for select to authenticated using (true);
create policy settlements_read on public.veyrath_settlements for select to authenticated using (true);
create policy characters_own on public.veyrath_characters for select to authenticated using (owner_id = (select auth.uid()));
create policy commands_own on public.veyrath_commands for select to authenticated using (owner_id = (select auth.uid()));
create policy events_read on public.veyrath_events for select to authenticated using (true);

insert into public.veyrath_worlds(slug,name) values ('veyrath-primordial','Veyrath');
insert into public.veyrath_settlements(world_id,name,region)
 select id,'Vale de Veyra','Valdória' from public.veyrath_worlds where slug='veyrath-primordial';

create function veyrath_private.register_character(p_world uuid,p_name text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_owner uuid := auth.uid(); v_row public.veyrath_characters%rowtype;
begin
 if v_owner is null then raise exception 'authentication required'; end if;
 if p_name is null or length(trim(p_name)) not between 1 and 40 then raise exception 'invalid name'; end if;
 if not exists (select 1 from public.veyrath_worlds where id=p_world) then raise exception 'world not found'; end if;
 insert into public.veyrath_characters(owner_id,world_id,name) values(v_owner,p_world,trim(p_name))
 on conflict(owner_id,world_id) do nothing;
 select * into strict v_row from public.veyrath_characters where owner_id=v_owner and world_id=p_world;
 return jsonb_build_object('id',v_row.id,'world_id',v_row.world_id,'name',v_row.name,'credits',v_row.credits,'version',v_row.version);
end $$;
create function public.veyrath_register_character(p_world uuid,p_name text) returns jsonb
language sql security invoker set search_path = '' as $$ select veyrath_private.register_character(p_world,p_name) $$;

create function veyrath_private.submit_contribution(p_actor uuid,p_settlement uuid,p_key uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_owner uuid := auth.uid(); v_actor public.veyrath_characters%rowtype; v_existing public.veyrath_commands%rowtype; v_cmd public.veyrath_commands%rowtype;
begin
 if v_owner is null then raise exception 'authentication required'; end if;
 if p_key is null then raise exception 'idempotency key required'; end if;
 select * into v_actor from public.veyrath_characters where id=p_actor and owner_id=v_owner for update;
 if not found then raise exception 'actor unavailable'; end if;
 select * into v_existing from public.veyrath_commands where owner_id=v_owner and idempotency_key=p_key;
 if found then
  if v_existing.actor_id<>p_actor or v_existing.settlement_id<>p_settlement or v_existing.kind<>'contribute_supplies' then raise exception 'idempotency key reused for different command'; end if;
  return jsonb_build_object('id',v_existing.id,'status',v_existing.status,'available_at',v_existing.available_at);
 end if;
 if not exists (select 1 from public.veyrath_settlements where id=p_settlement and world_id=v_actor.world_id) then raise exception 'settlement unavailable'; end if;
 if v_actor.credits < 2 then raise exception 'insufficient credits'; end if;
 if (select count(*) from public.veyrath_commands where actor_id=p_actor and status='pending') >= 3 then raise exception 'too many pending commands'; end if;
 insert into public.veyrath_commands(owner_id,actor_id,world_id,settlement_id,idempotency_key,kind,available_at)
 values(v_owner,p_actor,v_actor.world_id,p_settlement,p_key,'contribute_supplies',now()+interval '10 minutes') returning * into v_cmd;
 return jsonb_build_object('id',v_cmd.id,'status',v_cmd.status,'available_at',v_cmd.available_at);
end $$;
create function public.veyrath_submit_contribution(p_actor uuid,p_settlement uuid,p_key uuid) returns jsonb
language sql security invoker set search_path = '' as $$ select veyrath_private.submit_contribution(p_actor,p_settlement,p_key) $$;

-- Private worker. Only backend owner may execute; never grant it to clients.
create function veyrath_private.process_due(p_limit integer default 50) returns integer
language plpgsql security definer set search_path = '' as $$
declare c public.veyrath_commands%rowtype; v_credits bigint; v_version bigint; v_count integer := 0;
begin
 if p_limit < 1 or p_limit > 100 then raise exception 'invalid batch size'; end if;
 for c in select * from public.veyrath_commands where status='pending' and available_at<=now() order by available_at,created_at,id for update skip locked limit p_limit loop
  select credits into v_credits from public.veyrath_characters where id=c.actor_id for update;
  if v_credits < 2 then
   update public.veyrath_commands set status='rejected',processed_at=now(),rejection_reason='insufficient_credits' where id=c.id;
  else
   update public.veyrath_characters set credits=credits-2,version=version+1 where id=c.actor_id;
   update public.veyrath_settlements set public_supplies=public_supplies+2,version=version+1 where id=c.settlement_id;
   update public.veyrath_worlds set version=version+1 where id=c.world_id returning version into v_version;
   insert into public.veyrath_events(world_id,settlement_id,command_id,kind,description,world_version)
    values(c.world_id,c.settlement_id,c.id,c.kind,'Uma contribuição reforçou os suprimentos da cidade.',v_version);
   update public.veyrath_commands set status='applied',processed_at=now() where id=c.id;
  end if;
  v_count := v_count+1;
 end loop;
 return v_count;
end $$;
revoke all on function veyrath_private.register_character(uuid,text), veyrath_private.submit_contribution(uuid,uuid,uuid), veyrath_private.process_due(integer) from public, anon, authenticated;
revoke all on function public.veyrath_register_character(uuid,text), public.veyrath_submit_contribution(uuid,uuid,uuid) from public, anon, authenticated;
grant execute on function veyrath_private.register_character(uuid,text), veyrath_private.submit_contribution(uuid,uuid,uuid) to authenticated;
grant execute on function public.veyrath_register_character(uuid,text), public.veyrath_submit_contribution(uuid,uuid,uuid) to authenticated;
