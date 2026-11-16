-- Book1 1.9.8 SQL v70: include Tower Defense rewards in shared player XP.
-- Keep the server-side XP total aligned with the browser-side playerProgress calculation.
DO $$
DECLARE
  f text;
  old_expr text := $old$return xp+gd+bd
    + floor(greatest(0,coalesce((p_data->'pinballArchivedXP'->>p_player)::numeric,0)))::int$old$;
  new_expr text := $new$return xp+gd+bd
    + floor(greatest(0,coalesce((p_data->'pinballArchivedXP'->>p_player)::numeric,0)))::int
    + (
      select coalesce(sum(floor(greatest(0,coalesce((x->>'score')::numeric,0))/20)),0)::int
      from jsonb_array_elements(coalesce(p_data->'towerDefenseScores','[]'::jsonb)) x
      where x->>'player'=p_player
    )$new$;
BEGIN
  SELECT pg_get_functiondef('public.book_player_xp(jsonb,text)'::regprocedure) INTO f;
  IF position(old_expr in f)=0 THEN
    RAISE EXCEPTION 'Could not find expected book_player_xp return expression; no changes applied';
  END IF;
  f := replace(f, old_expr, new_expr);
  IF position(new_expr in f)=0 THEN
    RAISE EXCEPTION 'Tower Defense XP expression verification failed';
  END IF;
  EXECUTE f;
END $$;

CREATE OR REPLACE FUNCTION public.book_version()
RETURNS integer LANGUAGE sql SET search_path TO 'public','extensions'
AS $function$ SELECT 70 $function$;
