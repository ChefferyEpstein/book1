create or replace function public.book_player_xp(p_data jsonb, p_player text)
returns integer
language plpgsql
stable
set search_path to 'public','extensions'
as $function$
declare
  w jsonb;
  g jsonb;
  xp integer:=0;
  gd integer;
  bd integer;
  pinball_reset_at bigint:=coalesce((p_data->>'pinballXPResetAt')::bigint,0);
begin
  for w in select value from jsonb_array_elements(coalesce(p_data->'weeks','[]'::jsonb)) loop
    for g in select value from jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) loop
      if g->>'s1' is null or (g->>'p1'<>p_player and g->>'p2'<>p_player) then continue; end if;
      xp:=xp+100;
      if (((g->>'s1')::int>(g->>'s2')::int and g->>'p1'=p_player) or ((g->>'s2')::int>(g->>'s1')::int and g->>'p2'=p_player)) then xp:=xp+200; end if;
      gd:=case when g->>'p1'=p_player then (g->>'s1')::int-(g->>'s2')::int else (g->>'s2')::int-(g->>'s1')::int end;
      if gd>0 then xp:=xp+gd*10; end if;
    end loop;
  end loop;
  for g in select value from jsonb_array_elements(coalesce(p_data->'connect4','[]'::jsonb)) loop
    if g->>'status' in ('done','draw') and (g->>'challenger'=p_player or g->>'opponent'=p_player) then xp:=xp+50; if g->>'winner'=p_player then xp:=xp+100; end if; end if;
  end loop;
  for g in select value from jsonb_array_elements(coalesce(p_data->'battleships','[]'::jsonb)) loop
    if g->>'status'='done' and (g->>'challenger'=p_player or g->>'opponent'=p_player) then xp:=xp+50; if g->>'winner'=p_player then xp:=xp+100; end if; end if;
  end loop;
  for g in select value from jsonb_array_elements(coalesce(p_data->'hogDuels','[]'::jsonb)) loop
    if g->>'status'='done' and (g->>'challenger'=p_player or g->>'opponent'=p_player) then xp:=xp+25; if g->>'winner'=p_player then xp:=xp+50; end if; end if;
  end loop;
  for g in select value from jsonb_array_elements(coalesce(p_data->'chess','[]'::jsonb)) loop
    if g->>'status' in ('done','draw') and (g->>'challenger'=p_player or g->>'opponent'=p_player) then
      xp:=xp+75; if g->>'winner'=p_player then xp:=xp+150; elsif g->>'status'='draw' then xp:=xp+50; end if;
    end if;
  end loop;
  select coalesce(sum(coalesce((x->>'xp')::int,0)),0)::int into gd
  from jsonb_array_elements(coalesce(p_data->'challengeClaims','[]'::jsonb)) x
  where x->>'player'=p_player;
  select coalesce(sum(coalesce((x->>'xp')::int,0)),0)::int into bd
  from jsonb_array_elements(coalesce(p_data->'brainClaims','[]'::jsonb)) x
  where x->>'player'=p_player;
  xp := xp + (select count(*)::int*100 from jsonb_each(coalesce(p_data->'predictionRewards','{}'::jsonb)) r where r.value->>p_player='true');
  return xp+gd+bd
    + floor(greatest(0,coalesce((p_data->'pinballArchivedXP'->>p_player)::numeric,0)))::int
    + (
      select coalesce(sum(floor(greatest(0,coalesce((x->>'score')::numeric,0))/100)),0)::int
      from jsonb_array_elements(coalesce(p_data->'pinballScores','[]'::jsonb)) x
      where x->>'player'=p_player
        and coalesce((x->>'at')::bigint,0)>=pinball_reset_at
    );
end
$function$;

create or replace function public.book_version()
returns integer
language sql
set search_path to 'public','extensions'
as $function$
  select 58
$function$;