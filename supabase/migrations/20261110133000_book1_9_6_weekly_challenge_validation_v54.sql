-- Book1.9.6 / SQL v54: align server-side weekly challenge validation with the current
-- client challenge definitions and support Bokémong battles stored with completedAt.

do $$
declare
  src text;
  old_pred text := $old$target:=case p_key when 'pred3' then 3 else 5 end;$old$;
  new_pred text := $new$target:=case p_key when 'pred3' then 9 else 15 end;$new$;
  old_bok text := $old$elsif p_key in ('bokplay1','bokwin1') then
    select count(*)::int into v
    from jsonb_array_elements(coalesce(d->'bokemongs'->'battles','[]'::jsonb)) x
    where (x->>'a'=p_player or x->>'b'=p_player)
      and coalesce((x->>'at')::bigint,0)>=challenge_start
      and (x->>'winner' is not null)
      and (p_key='bokplay1' or x->>'winner'=p_player);
    target:=1;
    reward:=case p_key when 'bokplay1' then 10000 else 15000 end;
    xp_reward:=case p_key when 'bokplay1' then 1500 else 2200 end;$old$;
  new_bok text := $new$elsif p_key in ('bokplay1','bokwin1') then
    select count(*)::int into v
    from jsonb_array_elements(coalesce(d->'bokemongs'->'battles','[]'::jsonb)) x
    where (x->>'a'=p_player or x->>'b'=p_player)
      and coalesce(nullif(x->>'completedAt','')::bigint,nullif(x->>'at','')::bigint,0)>=challenge_start
      and (x->>'winner' is not null)
      and (p_key='bokplay1' or x->>'winner'=p_player);
    target:=1;
    reward:=case p_key when 'bokplay1' then 10000 else 15000 end;
    xp_reward:=case p_key when 'bokplay1' then 1500 else 2200 end;$new$;
  old_spins text := $old$target:=case p_key when 'spins2' then 2 else 5 end;$old$;
  new_spins text := $new$target:=case p_key when 'spins2' then 20 else 50 end;$new$;
begin
  select pg_get_functiondef('public.book_weekly_challenge_189(jsonb,text,text)'::regprocedure) into src;
  if length(src)-length(replace(src,old_pred,'')) <> length(old_pred) then
    raise exception 'Expected exactly one old prediction target definition';
  end if;
  if length(src)-length(replace(src,old_bok,'')) <> length(old_bok) then
    raise exception 'Expected exactly one old Bokémong validation block';
  end if;
  if length(src)-length(replace(src,old_spins,'')) <> length(old_spins) then
    raise exception 'Expected exactly one old casino target definition';
  end if;
  src:=replace(src,old_pred,new_pred);
  src:=replace(src,old_bok,new_bok);
  src:=replace(src,old_spins,new_spins);
  execute src;
end $$;
