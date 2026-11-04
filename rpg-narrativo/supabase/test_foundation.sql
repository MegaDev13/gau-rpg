-- Synthetic users and changes are always rolled back. Run only on a test/development database.
begin;
do $$
declare u1 uuid := gen_random_uuid(); u2 uuid := gen_random_uuid(); w uuid; town uuid; char1 uuid; key1 uuid := gen_random_uuid(); cmd uuid; one jsonb; two jsonb; supplies_before bigint; before_version bigint; n integer;
begin
 insert into auth.users(id,email) values (u1, 'test-'||u1||'@example.invalid'),(u2, 'test-'||u2||'@example.invalid');
 select id,version into strict w,before_version from public.veyrath_worlds where slug='veyrath-primordial';
 select id,public_supplies into strict town,supplies_before from public.veyrath_settlements where world_id=w limit 1;
 perform set_config('request.jwt.claim.sub',u1::text,true);
 execute 'set local role authenticated';
 one := public.veyrath_register_character(w,'Pessoa de teste');
 char1 := (one->>'id')::uuid;
 one := public.veyrath_submit_contribution(char1,town,key1);
 two := public.veyrath_submit_contribution(char1,town,key1);
 if one->>'id' <> two->>'id' then raise exception 'idempotency failed'; end if;
 cmd := (one->>'id')::uuid;
 if (select count(*) from public.veyrath_commands where owner_id=u1) <> 1 then raise exception 'duplicate command'; end if;
 execute 'reset role';
 if veyrath_private.process_due(50) <> 0 then raise exception 'executed before deadline'; end if;
 if (select credits from public.veyrath_characters where id=char1) <> 5 then raise exception 'premature debit'; end if;
 perform set_config('request.jwt.claim.sub',u2::text,true);
 execute 'set local role authenticated';
 if (select count(*) from public.veyrath_characters where id=char1) <> 0 then raise exception 'RLS leaked other character'; end if;
 begin
  perform public.veyrath_submit_contribution(char1,town,gen_random_uuid());
  raise exception 'unauthorized command was accepted';
 exception when raise_exception then
  if sqlerrm='unauthorized command was accepted' then raise; end if;
 end;
 execute 'reset role';
 update public.veyrath_commands set available_at=now()-interval '1 second' where id=cmd;
 n := veyrath_private.process_due(50);
 if n <> 1 then raise exception 'expected one processed command, got %',n; end if;
 if (select status from public.veyrath_commands where id=cmd) <> 'applied' then raise exception 'not applied'; end if;
 if (select credits from public.veyrath_characters where id=char1) <> 3 then raise exception 'wrong debit'; end if;
 if (select public_supplies from public.veyrath_settlements where id=town) <> supplies_before+2 then raise exception 'wrong supplies'; end if;
 if (select version from public.veyrath_worlds where id=w) <> before_version+1 then raise exception 'wrong world version'; end if;
 if veyrath_private.process_due(50) <> 0 then raise exception 'duplicate processing'; end if;
 if (select count(*) from public.veyrath_events where command_id=cmd) <> 1 then raise exception 'duplicate event'; end if;
end $$;
rollback;
