-- Book1.9.4 SQL v45: remove the time-based Pinball score ceiling.
-- Valid session tokens, 90-second expiry, minimum play time and duplicate-finish
-- protection remain in book_pinball_finish. Only the arbitrary score-rate check
-- is removed, so legitimately earned high scores can be submitted.
do $$
declare
  src text;
  old_check text := E'if p_score>greatest(250,floor((elapsed::numeric/1000)*180)::int) then\n    raise exception ''That score is too high for the time played.'';\n  end if;';
begin
  select pg_get_functiondef('public.book_pinball_finish(text,text,text,integer)'::regprocedure)
    into src;

  if position(old_check in src) = 0 then
    raise exception 'Expected Pinball time-based score ceiling was not found; refusing to alter function';
  end if;

  src := replace(src, old_check, '');
  execute src;
end
$$;

create or replace function public.book_version()
returns integer
language sql
stable
set search_path to 'public', 'extensions'
as $$
  select 45;
$$;
