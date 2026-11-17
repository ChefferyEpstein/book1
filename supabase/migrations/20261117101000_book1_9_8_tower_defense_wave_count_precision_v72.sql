-- Book1 1.9.8 SQL v72: mirror JavaScript floating-point wave sizing exactly.
-- Wave 48 rounds to 203 in the client (not 202); this keeps the server spawn allowance aligned.
DO $$
DECLARE
  f text;
  old_expr text := $old$sum(ceil((8+g*2+0.025*g*g)*1.25)::int)$old$;
  new_expr text := $new$sum(ceil((8::double precision+g*2+0.025::double precision*g*g)*1.25::double precision)::int)$new$;
BEGIN
  SELECT pg_get_functiondef('public.book_tower_defense_finish(text,text,text,jsonb)'::regprocedure) INTO f;
  IF position(old_expr in f)=0 THEN
    RAISE EXCEPTION 'Could not find expected v71 Tower Defense wave-count expression; no changes applied';
  END IF;
  f:=replace(f,old_expr,new_expr);
  IF position(new_expr in f)=0 THEN
    RAISE EXCEPTION 'Tower Defense JavaScript wave-count alignment verification failed';
  END IF;
  EXECUTE f;
END $$;

CREATE OR REPLACE FUNCTION public.book_version()
RETURNS integer LANGUAGE sql SET search_path TO 'public','extensions'
AS $function$ SELECT 72 $function$;
