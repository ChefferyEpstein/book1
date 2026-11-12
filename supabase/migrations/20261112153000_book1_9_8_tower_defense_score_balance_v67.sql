-- Book1 1.9.8 SQL v67: align Tower Defense score validation with reduced score generation.
DO $$
DECLARE f text;
BEGIN
 SELECT pg_get_functiondef('public.book_tower_defense_finish(text,text,text,jsonb)'::regprocedure) INTO f;
 IF position('sc>kw*120+wv*600+lv*2' in f)=0 THEN
  RAISE EXCEPTION 'Expected Tower Defense score validation expression was not found';
 END IF;
 f:=replace(f,'sc>kw*120+wv*600+lv*2','sc>kw*60+wv*20');
 EXECUTE f;
END $$;

CREATE OR REPLACE FUNCTION public.book_version()
RETURNS integer
LANGUAGE sql
SET search_path TO 'public', 'extensions'
AS $function$ SELECT 67 $function$;
