-- Book1 1.9.8: validate prestige against the authoritative XP balance (SQL v79)
DO $$
DECLARE
  fn text;
  old_clause text := 'if wi - coalesce((g->>''xpOffset'')::int,0) < public.book_prestige_xp_required_for(coalesce((g->>''prestige'')::int,0)) then';
  new_clause text := 'if coalesce((g->>''xpBalance'')::int, greatest(0,wi - coalesce((g->>''xpOffset'')::int,0))) < public.book_prestige_xp_required_for(coalesce((g->>''prestige'')::int,0)) then';
BEGIN
  fn := pg_get_functiondef('public.book_player_action(text,text,jsonb)'::regprocedure);
  IF position(old_clause in fn)=0 THEN
    RAISE EXCEPTION 'Could not locate the existing prestige XP validation clause; migration stopped.';
  END IF;
  EXECUTE replace(fn,old_clause,new_clause);
END
$$;

CREATE OR REPLACE FUNCTION public.book_version()
RETURNS integer LANGUAGE sql STABLE SET search_path TO 'public','extensions'
AS $function$ SELECT 79; $function$;
