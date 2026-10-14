-- Book1 1.8.11 — progressive Prestige XP curve
-- Database function version: 34

create or replace function public.book_prestige_xp_required_for(p_prestige integer)
returns integer
language sql
immutable
set search_path = public, extensions
as $function$
  select case
    when coalesce(p_prestige,0) <= 4 then 20000 + greatest(0,coalesce(p_prestige,0)) * 5000
    when p_prestige = 5 then 50000
    when p_prestige = 6 then 60000
    when p_prestige = 7 then 75000
    when p_prestige = 8 then 90000
    when p_prestige = 9 then 110000
    else 130000 + (p_prestige - 10) * 20000
  end
$function$;

do $patch$
declare
  f text;
  original text;
begin
  select pg_get_functiondef(p.oid) into f
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='book_player_action'
  order by p.oid desc limit 1;

  if f is null then raise exception 'book_player_action not found'; end if;
  original := f;

  f := replace(
    f,
    'if wi - coalesce((g->>''xpOffset'')::int,0) < public.book_prestige_xp_required() then raise exception ''Reach level 25 first.''; end if;',
    'if wi - coalesce((g->>''xpOffset'')::int,0) < public.book_prestige_xp_required_for(coalesce((g->>''prestige'')::int,0)) then
      raise exception ''Reach % XP for your next prestige first.'', public.book_prestige_xp_required_for(coalesce((g->>''prestige'')::int,0));
    end if;'
  );

  if f = original or position('book_prestige_xp_required_for' in f)=0 then
    raise exception 'prestige gate patch incomplete';
  end if;

  execute f;
end
$patch$;

create or replace function public.book_version()
returns integer
language sql
set search_path = public, extensions
as $function$
  select 34
$function$;
