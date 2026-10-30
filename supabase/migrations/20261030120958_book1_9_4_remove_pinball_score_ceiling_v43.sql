-- Book1.9.4: remove the fixed 8,000-point Pinball ceiling.
-- Keep the elapsed-time score sanity check in place to reject impossible submissions.
do $$
declare
  src text;
begin
  select pg_get_functiondef('public.book_pinball_finish(text,text,text,integer)'::regprocedure)
    into src;
  if position(' or p_score>8000' in src)=0 then
    raise exception 'Expected Pinball 8,000-point ceiling was not found; refusing to alter function';
  end if;
  src := replace(src, ' or p_score>8000', '');
  execute src;
end
$$;
