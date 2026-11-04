
CREATE TABLE IF NOT EXISTS public.veyrath_gm_state (
 world_id uuid PRIMARY KEY REFERENCES public.veyrath_worlds(id) ON DELETE CASCADE,
 state jsonb NOT NULL DEFAULT '{"active_arcs":[],"world_pressures":{},"faction_memory":{},"unresolved_hooks":[]}'::jsonb,
 last_cycle_hour timestamptz,
 version bigint NOT NULL DEFAULT 0 CHECK (version >= 0),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT veyrath_gm_state_object CHECK (jsonb_typeof(state) = 'object')
);
CREATE TABLE IF NOT EXISTS public.veyrath_gm_cycles (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 world_id uuid NOT NULL REFERENCES public.veyrath_worlds(id) ON DELETE CASCADE,
 cycle_hour timestamptz NOT NULL,
 observed_world_version bigint NOT NULL CHECK (observed_world_version >= 0),
 observed_command_count integer NOT NULL DEFAULT 0 CHECK (observed_command_count >= 0),
 summary text NOT NULL CHECK (char_length(summary) BETWEEN 1 AND 4000),
 analysis jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT veyrath_gm_cycles_unique_hour UNIQUE(world_id,cycle_hour)
);
CREATE TABLE IF NOT EXISTS public.veyrath_gm_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 cycle_id uuid NOT NULL REFERENCES public.veyrath_gm_cycles(id) ON DELETE RESTRICT,
 world_id uuid NOT NULL REFERENCES public.veyrath_worlds(id) ON DELETE CASCADE,
 settlement_id uuid REFERENCES public.veyrath_settlements(id) ON DELETE SET NULL,
 event_order integer NOT NULL DEFAULT 1 CHECK (event_order BETWEEN 1 AND 5),
 scope text NOT NULL CHECK (scope IN ('local','regional','global')),
 kind text NOT NULL CHECK (char_length(kind) BETWEEN 1 AND 64),
 title text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 160),
 narrative text NOT NULL CHECK (char_length(narrative) BETWEEN 1 AND 8000),
 causes jsonb NOT NULL DEFAULT '[]'::jsonb,
 consequences jsonb NOT NULL DEFAULT '[]'::jsonb,
 future_hooks jsonb NOT NULL DEFAULT '[]'::jsonb,
 visibility text NOT NULL DEFAULT 'public' CHECK (visibility IN ('public','secret')),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (cycle_id,event_order)
);
CREATE INDEX IF NOT EXISTS veyrath_gm_events_by_world ON public.veyrath_gm_events(world_id,created_at DESC);
CREATE INDEX IF NOT EXISTS veyrath_gm_cycles_by_world ON public.veyrath_gm_cycles(world_id,cycle_hour DESC);
ALTER TABLE public.veyrath_gm_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.veyrath_gm_cycles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.veyrath_gm_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.veyrath_gm_state FROM anon,authenticated;
REVOKE ALL ON public.veyrath_gm_cycles FROM anon,authenticated;
REVOKE ALL ON public.veyrath_gm_events FROM anon,authenticated;
GRANT SELECT ON public.veyrath_gm_events TO authenticated;
CREATE POLICY veyrath_gm_events_public_select ON public.veyrath_gm_events FOR SELECT TO authenticated USING (visibility='public');
INSERT INTO public.veyrath_gm_state(world_id)
SELECT id FROM public.veyrath_worlds ON CONFLICT (world_id) DO NOTHING;

