CREATE OR REPLACE FUNCTION public.book_weekly_challenge_189(p_data jsonb, p_player text, p_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  d jsonb:=p_data;
  w jsonb;
  wn int;
  v int:=0;
  target int:=0;
  reward int:=0;
  xp_reward int:=0;
  challenge_start bigint:=0;
begin
  if jsonb_array_length(coalesce(d->'weeks','[]'::jsonb))=0 then
    return jsonb_build_object('active',false,'done',false);
  end if;
  w:=d->'weeks'->(jsonb_array_length(d->'weeks')-1);
  wn:=(w->>'n')::int;
  challenge_start:=coalesce((d->>'challengeWeekStartedAt')::bigint,0);

  if p_key in ('wins3','wins5','wins6') then
    select count(*)::int into v from jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) x
    where x->>'s1' is not null and
      (((x->>'s1')::int>(x->>'s2')::int and x->>'p1'=p_player) or
       ((x->>'s2')::int>(x->>'s1')::int and x->>'p2'=p_player));
    target:=case p_key when 'wins3' then 3 when 'wins5' then 5 else 6 end;
    reward:=case p_key when 'wins3' then 10000 when 'wins5' then 15000 else 25000 end;
    xp_reward:=case p_key when 'wins3' then 1800 when 'wins5' then 2700 else 3600 end;
  elsif p_key in ('play2','play4','play6') then
    select count(*)::int into v from jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) x
    where x->>'s1' is not null and (x->>'p1'=p_player or x->>'p2'=p_player);
    target:=case p_key when 'play2' then 2 when 'play4' then 4 else 6 end;
    reward:=case p_key when 'play2' then 5000 when 'play4' then 7500 else 15000 end;
    xp_reward:=case p_key when 'play2' then 900 when 'play4' then 1500 else 2400 end;
  elsif p_key in ('diff5','diff10','diff15') then
    select coalesce(sum(case when x->>'p1'=p_player then (x->>'s1')::int-(x->>'s2')::int else (x->>'s2')::int-(x->>'s1')::int end),0)::int into v
    from jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) x
    where x->>'s1' is not null and (x->>'p1'=p_player or x->>'p2'=p_player);
    target:=case p_key when 'diff5' then 5 when 'diff10' then 10 else 15 end;
    reward:=case p_key when 'diff5' then 7500 when 'diff10' then 10000 else 17500 end;
    xp_reward:=case p_key when 'diff5' then 1800 when 'diff10' then 2700 else 3600 end;
  elsif p_key in ('c4wins2','c4wins4') then
    select count(*)::int into v from jsonb_array_elements(coalesce(d->'connect4','[]'::jsonb)) x
    where x->>'status'='done' and x->>'winner'=p_player
      and (coalesce((x->>'week')::int,-1)=wn or (x->>'week' is null and coalesce((x->>'createdAt')::bigint,0)>=challenge_start));
    target:=case p_key when 'c4wins2' then 2 else 4 end;
    reward:=case p_key when 'c4wins2' then 7500 else 15000 end;
    xp_reward:=case p_key when 'c4wins2' then 900 else 1800 end;
  elsif p_key in ('bswin1','bswin2') then
    select count(*)::int into v from jsonb_array_elements(coalesce(d->'battleships','[]'::jsonb)) x
    where x->>'status'='done' and x->>'winner'=p_player
      and (coalesce((x->>'week')::int,-1)=wn or (x->>'week' is null and coalesce((x->>'createdAt')::bigint,0)>=challenge_start));
    target:=case p_key when 'bswin1' then 1 else 2 end;
    reward:=case p_key when 'bswin1' then 7500 else 15000 end;
    xp_reward:=case p_key when 'bswin1' then 900 else 1800 end;
  elsif p_key in ('hogwin1','hogwin2') then
    select count(*)::int into v from jsonb_array_elements(coalesce(d->'hogDuels','[]'::jsonb)) x
    where x->>'status'='done' and x->>'winner'=p_player and coalesce((x->>'week')::int,-1)=wn;
    target:=case p_key when 'hogwin1' then 1 else 2 end;
    reward:=case p_key when 'hogwin1' then 5000 else 10000 end;
    xp_reward:=case p_key when 'hogwin1' then 700 else 1400 end;
  elsif p_key in ('chesswin1','chesswin2') then
    select count(*)::int into v from jsonb_array_elements(coalesce(d->'chess','[]'::jsonb)) x
    where x->>'status'='done' and x->>'winner'=p_player
      and coalesce((x->>'createdAt')::bigint,0)>=challenge_start;
    target:=case p_key when 'chesswin1' then 1 else 2 end;
    reward:=case p_key when 'chesswin1' then 7500 else 15000 end;
    xp_reward:=case p_key when 'chesswin1' then 900 else 1800 end;
  elsif p_key in ('pinplays1','pinplays3','pinscore1000','pinscore3000') then
    select count(*)::int into v from jsonb_array_elements(coalesce(d->'pinballScores','[]'::jsonb)) x
    where x->>'player'=p_player and coalesce((x->>'week')::int,-1)=wn;
    if p_key in ('pinscore1000','pinscore3000') then
      select coalesce(max((x->>'score')::int),0)::int into v
      from jsonb_array_elements(coalesce(d->'pinballScores','[]'::jsonb)) x
      where x->>'player'=p_player and coalesce((x->>'week')::int,-1)=wn;
      target:=case p_key when 'pinscore1000' then 1000 else 3000 end;
    else
      target:=case p_key when 'pinplays1' then 1 else 3 end;
    end if;
    reward:=case p_key when 'pinplays1' then 5000 when 'pinplays3' then 10000 when 'pinscore1000' then 7500 else 15000 end;
    xp_reward:=case p_key when 'pinplays1' then 700 when 'pinplays3' then 1400 when 'pinscore1000' then 1000 else 2200 end;
  else
    return jsonb_build_object('active',false,'done',false,'week',wn);
  end if;
  return jsonb_build_object('active',true,'done',v>=target,'week',wn,'progress',v,'target',target,'reward',reward,'xp',xp_reward);
end
$function$;

CREATE OR REPLACE FUNCTION public.book_version()
 RETURNS integer
 LANGUAGE sql
 SET search_path TO 'public', 'extensions'
AS $function$ select 41 $function$;
