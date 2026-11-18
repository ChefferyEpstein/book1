
create or replace function public.book_fantasy_week_xp(p_data jsonb, p_player text)
returns integer
language sql
stable
set search_path to 'public', 'extensions'
as $function$
  with eligible as (
    select w.value as week_data, fw.value as fantasy_data,
      fw.value->'picks'->p_player as picks,
      fw.value->'captains'->>p_player as captain,
      fw.value->'tiers' as tiers
    from jsonb_array_elements(coalesce(p_data->'weeks','[]'::jsonb)) w(value)
    join lateral jsonb_each(coalesce(p_data->'fantasyWeeks','{}'::jsonb)) fw(key,value)
      on fw.key = w.value->>'n'
    where coalesce((w.value->>'closed')::boolean,false)
      and coalesce((fw.value->>'paid')::boolean,false)
      and jsonb_typeof(fw.value->'picks'->p_player) = 'array'
  ),
  per_pick as (
    select e.week_data,e.captain,e.tiers,pick.player,
      case
        when coalesce(e.tiers->'elite','[]'::jsonb) ? pick.player then 10
        when coalesce(e.tiers->'challenger','[]'::jsonb) ? pick.player then 15
        else 20
      end as win_points
    from eligible e
    cross join lateral jsonb_array_elements_text(e.picks) as pick(player)
  ),
  scored as (
    select p.player,p.captain,
      (
        (select count(*)::integer
         from jsonb_array_elements(coalesce(p.week_data->'fixtures','[]'::jsonb)) f
         where f->>'s1' is not null
           and (((f->>'s1')::integer > (f->>'s2')::integer and f->>'p1'=p.player)
             or ((f->>'s2')::integer > (f->>'s1')::integer and f->>'p2'=p.player))
        ) * p.win_points
        + 2 * coalesce((
          select sum(case
            when f->>'p1'=p.player then (f->>'s1')::integer-(f->>'s2')::integer
            when f->>'p2'=p.player then (f->>'s2')::integer-(f->>'s1')::integer
            else 0 end)
          from jsonb_array_elements(coalesce(p.week_data->'fixtures','[]'::jsonb)) f
          where f->>'s1' is not null and (f->>'p1'=p.player or f->>'p2'=p.player)
        ),0)
      ) * case when p.player=p.captain then 2 else 1 end as fantasy_points
    from per_pick p
  )
  select greatest(0,coalesce(sum(fantasy_points),0))::integer from scored;
$function$;

do $migration$
declare v_def text; v_old text; v_new text;
begin
  select pg_get_functiondef('public.book_open_case(text,text)'::regprocedure) into v_def;
  v_old := 'dupe_bonus int;';
  if position(v_old in v_def)=0 then raise exception 'Could not locate book_open_case declaration'; end if;
  v_def := replace(v_def,v_old,'dupe_bonus int; xp_award int;');

  v_old := 'd := jsonb_set(d, array[''caseOpens'', p_name], to_jsonb(coalesce((d->''caseOpens''->>p_name)::int, 0) + 1), true);';
  v_new := 'xp_award := case rarity when ''common'' then 25 when ''uncommon'' then 50 when ''rare'' then 100 when ''epic'' then 200 when ''legendary'' then 400 else 25 end;' || chr(10) ||
           '  d := jsonb_set(d, array[''caseXP'', p_name], to_jsonb(coalesce((d->''caseXP''->>p_name)::int,0) + xp_award), true);' || chr(10) ||
           '  ' || v_old;
  if position(v_old in v_def)=0 then raise exception 'Could not locate case-open counter'; end if;
  v_def := replace(v_def,v_old,v_new);

  v_old := 'return picked || jsonb_build_object(''duplicate'', already_owned, ''refund'', refund);';
  v_new := 'return picked || jsonb_build_object(''duplicate'', already_owned, ''refund'', refund, ''xpAwarded'', xp_award);';
  if position(v_old in v_def)=0 then raise exception 'Could not locate case-open return'; end if;
  v_def := replace(v_def,v_old,v_new);
  execute v_def;

  select pg_get_functiondef('public.book_player_xp(jsonb,text)'::regprocedure) into v_def;
  v_old := 'return xp+gd+bd';
  v_new := 'return xp+gd+bd + coalesce((p_data->''caseXP''->>p_player)::integer,0) + public.book_fantasy_week_xp(p_data,p_player)';
  if position(v_old in v_def)=0 then raise exception 'Could not locate player XP return'; end if;
  v_def := replace(v_def,v_old,v_new);
  execute v_def;
end
$migration$;

create or replace function public.book_version()
returns integer language sql stable
set search_path to 'public','extensions'
as $function$ select 75; $function$;
