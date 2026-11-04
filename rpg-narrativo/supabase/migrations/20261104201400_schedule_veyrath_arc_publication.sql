create extension if not exists pg_cron;

-- This job can publish only due, independently reviewed candidates. Pending
-- proposals from the existing Master intake are never selected.
select cron.schedule(
  'veyrath-arc-publication',
  '10 * * * *',
  $job$
    select veyrath_private.publish_arc_candidates(w.id)
      from public.veyrath_worlds w
      where exists (
        select 1 from veyrath_private.gm_arc_proposals p
        where p.world_id = w.id and p.status = 'scheduled' and p.scheduled_at <= now()
      )
      order by w.id
  $job$
);
