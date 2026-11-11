do $$
declare
  v_def text;
  v_old text := $old$elsif t = 'prestige' then
    d := jsonb_set(d,'{progression}',coalesce(d->'progression','{}'::jsonb),true);
    g := coalesce(d->'progression'->p_name,'{}'::jsonb);
    wi := public.book_player_xp(d,p_name);
    if wi - coalesce((g->>'xpOffset')::int,0) < public.book_prestige_xp_required_for(coalesce((g->>'prestige')::int,0)) then
      raise exception 'Reach % XP for your next prestige first.', public.book_prestige_xp_required_for(coalesce((g->>'prestige')::int,0));
    end if;
    d := jsonb_set(d,array['progression',p_name],jsonb_build_object(
      'prestige',coalesce((g->>'prestige')::int,0)+1,
      'xpOffset',wi,
      'at',(extract(epoch from now())*1000)::bigint
    ),true);$old$;
  v_new text := $new$elsif t = 'prestige' then
    d := jsonb_set(d,'{progression}',coalesce(d->'progression','{}'::jsonb),true);
    g := coalesce(d->'progression'->p_name,'{}'::jsonb);
    if coalesce((g->>'prestige')::int,0) >= 10 then
      raise exception 'Prestige Master is the final rank. There are no further prestiges.';
    end if;
    wi := public.book_player_xp(d,p_name);
    if wi - coalesce((g->>'xpOffset')::int,0) < public.book_prestige_xp_required_for(coalesce((g->>'prestige')::int,0)) then
      raise exception 'Reach % XP for your next prestige first.', public.book_prestige_xp_required_for(coalesce((g->>'prestige')::int,0));
    end if;
    d := jsonb_set(d,array['progression',p_name],jsonb_build_object(
      'prestige',least(10,coalesce((g->>'prestige')::int,0)+1),
      'xpOffset',wi,
      'at',(extract(epoch from now())*1000)::bigint
    ),true);$new$;
begin
  v_def := pg_get_functiondef('public.book_player_action(text,text,jsonb)'::regprocedure);
  if position(v_old in v_def) = 0 then
    raise exception 'Could not find expected prestige branch; refusing to alter function.';
  end if;
  execute replace(v_def, v_old, v_new);
end $$;

create or replace function public.book_version()
returns integer
language sql
set search_path to 'public', 'extensions'
as $function$ select 62 $function$;
