begin;
do $$
declare u1 uuid := gen_random_uuid(); u2 uuid := gen_random_uuid(); w uuid; town uuid; a uuid; cmd uuid; j jsonb; supplies_before bigint;
begin
 insert into auth.users(id,email) values (u1,'poll-'||u1||'@example.invalid'),(u2,'poll-'||u2||'@example.invalid');
 select id into strict w from public.veyrath_worlds where slug='veyrath-primordial';
 select id,public_supplies into strict town,supplies_before from public.veyrath_settlements where world_id=w limit 1;
 perform set_config('request.jwt.claim.sub',u1::text,true);
 execute 'set local role authenticated';
 j := public.veyrath_register_character(w,'Jogador A'); a := (j->>'id')::uuid;
 j := public.veyrath_submit_contribution(a,town,gen_random_uuid()); cmd := (j->>'id')::uuid;
 j := public.veyrath_poll_world(w);
 if j->>'status' <> 'ok' or (j->>'processed')::int <> 0 then raise exception 'event applied before due'; end if;
 j := public.veyrath_poll_world(w);
 if j->>'status' <> 'rate_limited' then raise exception 'rate limit failed'; end if;
 execute 'reset role';
 perform set_config('request.jwt.claim.sub',u2::text,true);
 execute 'set local role authenticated';
 begin
  perform public.veyrath_poll_world(w);
  raise exception 'nonmember accepted';
 exception when raise_exception then
  if sqlerrm='nonmember accepted' then raise; end if;
 end;
 perform public.veyrath_register_character(w,'Jogador B');
 execute 'reset role';
 update public.veyrath_commands set available_at=now()-interval '1 second' where id=cmd;
 execute 'set local role authenticated';
 j := public.veyrath_poll_world(w);
 if j->>'status' <> 'ok' or (j->>'processed')::int <> 1 then raise exception 'other player failed to process due event'; end if;
 if (select public_supplies from public.veyrath_settlements where id=town) <> supplies_before+2 then raise exception 'world effect incorrect'; end if;
 if (select count(*) from public.veyrath_events where command_id=cmd) <> 1 then raise exception 'event count incorrect'; end if;
 if (select count(*) from public.veyrath_characters where id=a) <> 0 then raise exception 'RLS failure'; end if;
 execute 'reset role';
 if (select credits from public.veyrath_characters where id=a) <> 3 then raise exception 'debit incorrect'; end if;
 if has_function_privilege('authenticated','veyrath_private.process_due(integer)','execute') then raise exception 'worker leaked'; end if;
end $$;
rollback;
