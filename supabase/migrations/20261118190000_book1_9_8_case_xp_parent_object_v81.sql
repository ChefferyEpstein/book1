-- Book1 1.9.8: ensure case XP parent object exists before writing player XP (SQL v81).
DO $migration$
DECLARE
  fn text;
  old_stmt text := 'd := jsonb_set(d, array[''caseXP'', p_name], to_jsonb(coalesce((d->''caseXP''->>p_name)::int,0) + xp_award), true);';
  new_stmt text := 'd := d || jsonb_build_object(''caseXP'', coalesce(d->''caseXP'', ''{}''::jsonb));' || chr(10) ||
                   '  d := jsonb_set(d, array[''caseXP'', p_name], to_jsonb(coalesce((d->''caseXP''->>p_name)::int,0) + xp_award), true);';
BEGIN
  fn := pg_get_functiondef('public.book_open_case(text,text)'::regprocedure);
  IF position(old_stmt in fn)=0 THEN
    RAISE EXCEPTION 'Expected case XP write was not found; migration stopped.';
  END IF;
  fn := replace(fn, old_stmt, new_stmt);
  EXECUTE fn;
END
$migration$;

CREATE OR REPLACE FUNCTION public.book_version()
RETURNS integer
LANGUAGE sql STABLE
SET search_path TO 'public','extensions'
AS $function$ SELECT 81; $function$;
