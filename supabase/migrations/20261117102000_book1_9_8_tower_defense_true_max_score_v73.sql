-- Book1 1.9.8 SQL v73: set the Tower Defense ceiling to the true perfect-run maximum.
-- The exact client wave generator produces 5,059 enemies across waves 1-50.
-- Their reward values (3,3,5,4,6,7,14) are multiplied by 4 for score:
-- total maximum kill score = 79,260.
-- Each of the 50 cleared waves adds remaining lives to score. A perfect run
-- leaks none of the initial 20 lives, so the maximum clear bonus is 50 * 20 = 1,000.
-- True maximum score = 79,260 + 1,000 = 80,260.
DO $$
DECLARE
  f text;
  old_check text := $old$OR sc>79260$old$;
  new_check text := $new$OR sc>80260$new$;
BEGIN
  SELECT pg_get_functiondef('public.book_tower_defense_finish(text,text,text,jsonb)'::regprocedure) INTO f;
  IF position(old_check in f)=0 THEN
    RAISE EXCEPTION 'Could not find expected v72 Tower Defense score ceiling; no changes applied';
  END IF;
  f:=replace(f,old_check,new_check);
  IF position(new_check in f)=0 THEN
    RAISE EXCEPTION 'Tower Defense score ceiling update verification failed';
  END IF;
  EXECUTE f;
END $$;

CREATE OR REPLACE FUNCTION public.book_version()
RETURNS integer LANGUAGE sql SET search_path TO 'public','extensions'
AS $function$ SELECT 73 $function$;
