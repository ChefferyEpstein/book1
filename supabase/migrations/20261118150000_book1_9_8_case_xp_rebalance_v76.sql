
do $migration$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  select pg_get_functiondef('public.book_open_case(text,text)'::regprocedure) into v_def;
  v_old := 'xp_award := case rarity when ''common'' then 25 when ''uncommon'' then 50 when ''rare'' then 100 when ''epic'' then 200 when ''legendary'' then 400 else 25 end;';
  v_new := 'xp_award := case rarity when ''common'' then 25 when ''uncommon'' then 50 when ''rare'' then 75 when ''epic'' then 150 when ''legendary'' then 250 else 25 end;';
  if position(v_old in v_def)=0 then
    raise exception 'Could not locate previous case XP reward table in book_open_case';
  end if;
  v_def := replace(v_def,v_old,v_new);
  execute v_def;
end
$migration$;

create or replace function public.book_version()
returns integer
language sql
stable
set search_path to 'public','extensions'
as $function$
  select 76;
$function$;
