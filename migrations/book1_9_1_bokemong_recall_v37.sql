-- Book1 1.9.1 — Bokémong challenge recall / DB v37
-- Adds sender-side recall for pending Bokémong challenges.

begin;

do $patch$
declare
  fn text;
begin
  select pg_get_functiondef('public.book_bokemong_action(text,text,jsonb)'::regprocedure) into fn;

  if position('bokemongRecall' in fn) = 0 then
    fn := replace(
      fn,
      'elsif t in (''bokemongAccept'',''bokemongDecline'',''bokemongMove'',''bokemongForfeit'') then',
      'elsif t in (''bokemongAccept'',''bokemongDecline'',''bokemongRecall'',''bokemongMove'',''bokemongForfeit'') then'
    );

    fn := replace(
      fn,
      '    elsif t=''bokemongDecline'' then',
      '    elsif t=''bokemongRecall'' then
      if g->>''status''<>''pending'' then raise exception ''That challenge is no longer pending''; end if;
      if g->>''a''<>p_name then raise exception ''Only the challenger can recall this battle''; end if;
      g:=g||jsonb_build_object(''status'',''recalled'',''completedAt'',now_ms);
      g:=jsonb_set(g,''{log}'',coalesce(g->''log'',''[]''::jsonb)||jsonb_build_array(p_name||'' recalled the challenge.''),true);

    elsif t=''bokemongDecline'' then'
    );

    execute fn;
  end if;
end
$patch$;

create or replace function public.book_version()
returns integer
language sql
set search_path = public, extensions
as $function$
  select 37
$function$;

commit;

select public.book_version() as version,
       position('bokemongRecall' in pg_get_functiondef('public.book_bokemong_action(text,text,jsonb)'::regprocedure)) > 0 as recall_installed;
