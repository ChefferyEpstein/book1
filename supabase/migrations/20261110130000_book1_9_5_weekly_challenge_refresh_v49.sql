-- Book1 v49: 500-chip correct prediction reward and varied weekly challenges.
CREATE OR REPLACE FUNCTION public.book_settle_json(d0 jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
declare d jsonb := d0; i int; j int; n int; b jsonb; g jsonb; pl text; stake int; pay int; cur int;
        lgs jsonb; lg jsonb; ls text; lost boolean; open_left boolean; anywon boolean; prod float8; eff float8;
        wi int; wk jsonb; fixture_id text; preds jsonb; pred_player text; pred_pick text;
begin
  if d->'bets' is null or jsonb_typeof(d->'bets') <> 'array' then
    d := jsonb_set(d, '{bets}', '[]'::jsonb, true);
  end if;
  d := d || jsonb_build_object(
    'chips', coalesce(d->'chips','{}'::jsonb),
    'log', coalesce(d->'log','[]'::jsonb),
    'predictionRewards', coalesce(d->'predictionRewards','{}'::jsonb)
  );
  n := jsonb_array_length(d->'bets');
  for i in 0 .. n-1 loop
    b := d->'bets'->i;
    if b->>'status' <> 'open' then continue; end if;
    pl := b->>'player'; stake := (b->>'stake')::int;
    cur := coalesce((d->'chips'->>pl)::int, 1000);
    if b ? 'legs' then
      lgs := b->'legs'; lost := false; open_left := false; anywon := false; prod := 1;
      for j in 0 .. jsonb_array_length(lgs) - 1 loop
        lg := lgs->j; ls := lg->>'status';
        if ls = 'open' then
          select x into g from jsonb_path_query(d, '$.** ? (@.id == $gid)', jsonb_build_object('gid', lg->>'game')) as x limit 1;
          if g is null or ((g->>'p1') is distinct from (lg->>'pick') and (g->>'p2') is distinct from (lg->>'pick')) then
            ls := 'void';
          elsif (g->>'s1') is not null then
            if (case when (g->>'s1')::int > (g->>'s2')::int then g->>'p1' else g->>'p2' end) = (lg->>'pick') then ls := 'won'; else ls := 'lost'; end if;
          end if;
          if ls <> (lg->>'status') then
            lgs := jsonb_set(lgs, array[j::text], lg || jsonb_build_object('status', ls));
          end if;
        end if;
        if ls = 'lost' then lost := true;
        elsif ls = 'open' then open_left := true;
        elsif ls = 'won' then prod := prod * (lg->>'odds')::float8; anywon := true;
        end if;
      end loop;
      b := b || jsonb_build_object('legs', lgs);
      if lost then
        d := jsonb_set(d, array['bets', i::text], b || jsonb_build_object('status','lost','payout',0));
        d := jsonb_set(d, '{log}', (d->'log') || to_jsonb(format('%s lost %s chips on an accumulator (%s)', pl, stake, coalesce(b->>'label',''))));
      elsif open_left then
        d := jsonb_set(d, array['bets', i::text], b);
      elsif not anywon then
        d := jsonb_set(d, array['chips', pl], to_jsonb(cur + stake));
        d := jsonb_set(d, array['bets', i::text], b || jsonb_build_object('status','void','payout',stake));
        d := jsonb_set(d, '{log}', (d->'log') || to_jsonb(format('Accumulator void, %s chips back to %s', stake, pl)));
      else
        eff := floor(least(200, prod)*100 + 0.5)/100;
        pay := floor(stake * eff + 0.5)::int;
        d := jsonb_set(d, array['chips', pl], to_jsonb(cur + pay));
        d := jsonb_set(d, array['bets', i::text], b || jsonb_build_object('status','won','payout',pay));
        d := jsonb_set(d, '{log}', (d->'log') || to_jsonb(format('%s won %s chips on an accumulator (%s)', pl, pay, coalesce(b->>'label',''))));
      end if;
      continue;
    end if;
    select x into g from jsonb_path_query(d, '$.** ? (@.id == $gid)', jsonb_build_object('gid', b->>'game')) as x limit 1;
    if g is null or ((g->>'p1') is distinct from (b->>'pick') and (g->>'p2') is distinct from (b->>'pick')) then
      d := jsonb_set(d, array['chips', pl], to_jsonb(cur + stake));
      d := jsonb_set(d, array['bets', i::text], b || jsonb_build_object('status','void','payout',stake));
      d := jsonb_set(d, '{log}', (d->'log') || to_jsonb(format('Bet void, %s chips back to %s (%s)', stake, pl, coalesce(b->>'label',''))));
      continue;
    end if;
    if (g->>'s1') is null then continue; end if;
    if ((case when (g->>'s1')::int > (g->>'s2')::int then g->>'p1' else g->>'p2' end) = (b->>'pick')) then
      pay := floor(stake * (b->>'odds')::numeric + 0.5)::int;
      d := jsonb_set(d, array['chips', pl], to_jsonb(cur + pay));
      d := jsonb_set(d, array['bets', i::text], b || jsonb_build_object('status','won','payout',pay));
      d := jsonb_set(d, '{log}', (d->'log') || to_jsonb(format('%s won %s chips betting on %s (%s)', pl, pay, b->>'pick', coalesce(b->>'label',''))));
    else
      d := jsonb_set(d, array['bets', i::text], b || jsonb_build_object('status','lost','payout',0));
      d := jsonb_set(d, '{log}', (d->'log') || to_jsonb(format('%s lost %s chips betting on %s (%s)', pl, stake, b->>'pick', coalesce(b->>'label',''))));
    end if;
  end loop;
  -- Settle correct predictions once, when their fixture receives a final score.
  for wi in 0 .. coalesce(jsonb_array_length(d->'weeks'),0)-1 loop
    wk := d->'weeks'->wi;
    for j in 0 .. coalesce(jsonb_array_length(wk->'fixtures'),0)-1 loop
      g := wk->'fixtures'->j;
      if g->>'s1' is null or g->>'s2' is null or g->>'id' is null then continue; end if;
      fixture_id := g->>'id';
      preds := d->'predictions'->fixture_id;
      if jsonb_typeof(preds) <> 'object' then continue; end if;
      if jsonb_typeof(d->'predictionRewards'->fixture_id) is distinct from 'object' then
        d := jsonb_set(d, array['predictionRewards',fixture_id], '{}'::jsonb, true);
      end if;
      for pred_player, pred_pick in select key, value from jsonb_each_text(preds) loop
        if pred_pick = (case when (g->>'s1')::int > (g->>'s2')::int then g->>'p1' else g->>'p2' end)
           and not coalesce((d #>> array['predictionRewards',fixture_id,pred_player])::boolean,false) then
          cur := coalesce((d->'chips'->>pred_player)::int,1000);
          d := jsonb_set(d, array['chips',pred_player], to_jsonb(cur+500), true);
          d := jsonb_set(d, array['predictionRewards',fixture_id,pred_player], 'true'::jsonb, true);
          d := jsonb_set(d, '{log}', (d->'log') || to_jsonb(format('%s correctly predicted %s to win (+500 chips and 100 XP)', pred_player, pred_pick)));
        end if;
      end loop;
    end loop;
  end loop;
  return d;
exception when others then
  return d0;
end $function$
;

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
    reward:=case p_key when 'bswin1' then 1 else 2 end;
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
  elsif p_key in ('pinplays3','pinplays5','pinscore50000','pinscore125000','pinscore200000','pinscore250000') then
    select count(*)::int into v from jsonb_array_elements(coalesce(d->'pinballScores','[]'::jsonb)) x
    where x->>'player'=p_player and coalesce((x->>'week')::int,-1)=wn;
    if p_key like 'pinscore%' then
      select coalesce(max((x->>'score')::int),0)::int into v
      from jsonb_array_elements(coalesce(d->'pinballScores','[]'::jsonb)) x
      where x->>'player'=p_player and coalesce((x->>'week')::int,-1)=wn;
      target:=case p_key when 'pinscore50000' then 50000 when 'pinscore125000' then 125000 when 'pinscore200000' then 200000 else 250000 end;
    else
      target:=case p_key when 'pinplays3' then 3 else 5 end;
    end if;
    reward:=case p_key when 'pinplays3' then 10000 when 'pinplays5' then 20000 when 'pinscore50000' then 10000 when 'pinscore125000' then 17500 when 'pinscore200000' then 25000 else 40000 end;
    xp_reward:=case p_key when 'pinplays3' then 1400 when 'pinplays5' then 2600 when 'pinscore50000' then 1500 when 'pinscore125000' then 2500 when 'pinscore200000' then 3500 else 5000 end;
  elsif p_key in ('pred3','pred5') then
    select count(*)::int into v
    from jsonb_each(coalesce(d->'predictionRewards','{}'::jsonb)) fixture
    where coalesce((fixture.value->>p_player)::boolean,false);
    target:=case p_key when 'pred3' then 3 else 5 end;
    reward:=case p_key when 'pred3' then 10000 else 20000 end;
    xp_reward:=case p_key when 'pred3' then 1500 else 3000 end;
  elsif p_key in ('bokplay1','bokwin1') then
    select count(*)::int into v
    from jsonb_array_elements(coalesce(d->'bokemongs'->'battles','[]'::jsonb)) x
    where (x->>'a'=p_player or x->>'b'=p_player)
      and coalesce((x->>'at')::bigint,0)>=challenge_start
      and (x->>'winner' is not null)
      and (p_key='bokplay1' or x->>'winner'=p_player);
    target:=1;
    reward:=case p_key when 'bokplay1' then 10000 else 15000 end;
    xp_reward:=case p_key when 'bokplay1' then 1500 else 2200 end;
  elsif p_key in ('spins2','spins5') then
    select count(*)::int into v
    from jsonb_array_elements(coalesce(d->'wheelSpinHistory','[]'::jsonb)) x
    where x->>'player'=p_player and coalesce((x->>'at')::bigint,0)>=challenge_start;
    target:=case p_key when 'spins2' then 2 else 5 end;
    reward:=case p_key when 'spins2' then 7500 else 15000 end;
    xp_reward:=case p_key when 'spins2' then 1000 else 2200 end;
  else
    return jsonb_build_object('active',false,'done',false,'week',wn);
  end if;
  return jsonb_build_object('active',true,'done',v>=target,'week',wn,'progress',v,'target',target,'reward',reward,'xp',xp_reward);
end
$function$
;

create or replace function public.book_version()
returns integer
language sql
set search_path to 'public', 'extensions'
as $function$
  select 49
$function$;
