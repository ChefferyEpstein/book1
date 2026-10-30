-- Change Pinball chip return to 5% of the final score.
-- The 100-chip entry fee remains unchanged; no historical scores or balances are rewritten.
do $$
declare
  ddl text;
begin
  select replace(
    pg_get_functiondef('public.book_pinball_finish(text,text,text,integer)'::regprocedure),
    'prize := case when p_score<500 then 0 when p_score<1000 then 250 when p_score<2000 then 625 when p_score<3500 then 1250 when p_score<5000 then 2500 else 5000 end;',
    'prize := floor(p_score::numeric * 0.05)::int;'
  ) into ddl;

  if ddl = pg_get_functiondef('public.book_pinball_finish(text,text,text,integer)'::regprocedure) then
    raise exception 'Expected Pinball prize calculation was not found; migration aborted.';
  end if;

  execute ddl;
end
$$;
