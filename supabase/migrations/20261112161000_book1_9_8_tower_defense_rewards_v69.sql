-- Book1 1.9.8 SQL v69: Tower Defense rewards are 5% XP and 10% chips.
-- The score is still validated by the existing server-side finish function.
DO $$
DECLARE f text;
BEGIN
 SELECT pg_get_functiondef('public.book_tower_defense_finish(text,text,text,jsonb)'::regprocedure) INTO f;
 IF position('xp:=floor(sc/200.0)::int; chips_reward:=floor(sc/100.0)::int;' in f)=0 THEN
  RAISE EXCEPTION 'Could not find the expected v68 Tower Defense reward calculation; no changes applied';
 END IF;
 f:=replace(f,
  'xp:=floor(sc/200.0)::int; chips_reward:=floor(sc/100.0)::int;',
  'xp:=floor(sc/20.0)::int; chips_reward:=floor(sc/10.0)::int;');
 IF position('xp:=floor(sc/20.0)::int; chips_reward:=floor(sc/10.0)::int;' in f)=0 THEN
  RAISE EXCEPTION 'Tower Defense reward update verification failed';
 END IF;
 EXECUTE f;
END $$;

CREATE OR REPLACE FUNCTION public.book_version()
RETURNS integer LANGUAGE sql SET search_path TO 'public','extensions'
AS $function$ SELECT 69 $function$;
