create index veyrath_characters_world_idx on public.veyrath_characters(world_id);
create index veyrath_commands_actor_world_idx on public.veyrath_commands(actor_id,world_id);
create index veyrath_commands_settlement_world_idx on public.veyrath_commands(settlement_id,world_id);
create index veyrath_events_settlement_world_idx on public.veyrath_events(settlement_id,world_id);
