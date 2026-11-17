-- Book1 1.9.8 SQL v71: validate Tower Defense kills against the real cumulative wave spawns.
-- Preserve the exact game score ceiling (79,260) and existing 5% XP / 10% chip rewards.
DO $$
DECLARE
  f text;
  old_parse text := $old$sc:=greatest(0,least(2000000,coalesce((p_stats->>'score')::int,0))); kw:=greatest(0,least(1000,coalesce((p_stats->>'kills')::int,0)));$old$;
  new_parse text := $new$sc:=greatest(0,coalesce((p_stats->>'score')::int,0)); kw:=greatest(0,coalesce((p_stats->>'kills')::int,0));$new$;
  old_check text := $old$IF wv>floor(elapsed/8.0)+1 OR kw>wv*30 OR sc>kw*60+wv*20 THEN RAISE EXCEPTION 'Tower Defense score failed server validation.'; END IF;$old$;
  new_check text := $new$IF wv>floor(elapsed/8.0)+1
    OR kw>coalesce((SELECT sum(ceil((8+g*2+0.025*g*g)*1.25)::int) FROM generate_series(1,wv) AS waves(g)),0)
    OR sc>79260
    OR sc>kw*56
  THEN RAISE EXCEPTION 'Tower Defense score failed server validation.'; END IF;$new$;
BEGIN
  SELECT pg_get_functiondef('public.book_tower_defense_finish(text,text,text,jsonb)'::regprocedure) INTO f;
  IF position(old_parse in f)=0 THEN
    RAISE EXCEPTION 'Could not find expected Tower Defense score/kill parsing; no changes applied';
  END IF;
  IF position(old_check in f)=0 THEN
    RAISE EXCEPTION 'Could not find expected Tower Defense validation; no changes applied';
  END IF;
  f:=replace(f,old_parse,new_parse);
  f:=replace(f,old_check,new_check);
  IF position(new_parse in f)=0 OR position(new_check in f)=0 THEN
    RAISE EXCEPTION 'Tower Defense validation update verification failed';
  END IF;
  EXECUTE f;
END $$;

CREATE OR REPLACE FUNCTION public.book_version()
RETURNS integer LANGUAGE sql SET search_path TO 'public','extensions'
AS $function$ SELECT 71 $function$;
