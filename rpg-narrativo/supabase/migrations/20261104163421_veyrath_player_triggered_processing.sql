-- Clients request work; the server owns time, validation, ordering, updates and events.
create table veyrath_private.player_polls (
 owner_id uuid primary key references auth.users(id) on delete cascade,
 last_poll_at timestamptz not null
);
alter table veyrath_private.player_polls enable row level security;
revoke all on veyrath_private.player_polls from public, anon, authenticated;

create function veyrath_private.poll_world(p_world uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
 v_owner uuid := auth.uid();
 v_now timestamptz := clock_timestamp();
 v_claim uuid;
 c public.veyrath_commands%rowtype;
 v_credits bigint;
 v_version bigint;
 v_count integer := 0;
begin
 if v_owner is null then raise exception 'authentication required'; end if;
 if not exists (select 1 from public.veyrath_characters where owner_id=v_owner and world_id=p_world) then
  raise exception 'not a member of this world';
 end if;
 -- A database-side throttle applies across all worlds and all devices of this account.
 insert into veyrath_private.player_polls(owner_id,last_poll_at) values(v_owner,v_now)
 on conflict(owner_id) do update set last_poll_at=excluded.last_poll_at
 where veyrath_private.player_polls.last_poll_at <= v_now - interval '30 seconds'
 returning owner_id into v_claim;
 if v_claim is null then
  return jsonb_build_object('status','rate_limited','processed',0,'server_time',v_now);
 end if;
 -- The caller cannot select individual commands, fabricate time, results or balances.
 for c in select * from public.veyrath_commands
  where world_id=p_world and status='pending' and available_at<=v_now
  order by available_at,created_at,id for update skip locked limit 10
 loop
  select credits into v_credits from public.veyrath_characters where id=c.actor_id for update;
  if v_credits < 2 then
   update public.veyrath_commands set status='rejected',processed_at=v_now,rejection_reason='insufficient_credits' where id=c.id;
  else
   update public.veyrath_characters set credits=credits-2,version=version+1 where id=c.actor_id;
   update public.veyrath_settlements set public_supplies=public_supplies+2,version=version+1 where id=c.settlement_id;
   update public.veyrath_worlds set version=version+1 where id=c.world_id returning version into v_version;
   insert into public.veyrath_events(world_id,settlement_id,command_id,kind,description,world_version)
    values(c.world_id,c.settlement_id,c.id,c.kind,'Uma contribuição reforçou os suprimentos da cidade.',v_version);
   update public.veyrath_commands set status='applied',processed_at=v_now where id=c.id;
  end if;
  v_count := v_count + 1;
 end loop;
 return jsonb_build_object('status','ok','processed',v_count,'server_time',v_now);
end $$;
create function public.veyrath_poll_world(p_world uuid) returns jsonb
language sql security invoker set search_path = '' as $$ select veyrath_private.poll_world(p_world) $$;
revoke all on function veyrath_private.poll_world(uuid), public.veyrath_poll_world(uuid) from public, anon, authenticated;
grant execute on function veyrath_private.poll_world(uuid), public.veyrath_poll_world(uuid) to authenticated;
