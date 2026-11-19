-- Book1 1.9.8: sync every live weekly challenge to server-side validation (SQL v82).
CREATE OR REPLACE FUNCTION public.book_weekly_challenge_189(p_data jsonb, p_player text, p_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
declare
 d jsonb:=p_data; w jsonb; wn int; v int:=0; target int:=0; reward int:=0; xp_reward int:=0;
 challenge_start bigint:=0; pinball_reset_at bigint:=0;
begin
 if jsonb_array_length(coalesce(d->'weeks','[]'::jsonb))=0 then return jsonb_build_object('active',false,'done',false); end if;
 w:=d->'weeks'->(jsonb_array_length(d->'weeks')-1); wn:=(w->>'n')::int;
 challenge_start:=coalesce((d->>'challengeWeekStartedAt')::bigint,0);
 pinball_reset_at:=coalesce((d->>'pinballLeaderboardResetAt')::bigint,0);
 if p_key in ('wins3','wins5','wins6') then
  select count(*)::int into v from jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) x
  where x->>'s1' is not null and (((x->>'s1')::int>(x->>'s2')::int and x->>'p1'=p_player) or ((x->>'s2')::int>(x->>'s1')::int and x->>'p2'=p_player));
  target:=case p_key when 'wins3' then 3 when 'wins5' then 5 else 6 end;
  reward:=case p_key when 'wins3' then 10000 when 'wins5' then 15000 else 25000 end;
  xp_reward:=case p_key when 'wins3' then 1800 when 'wins5' then 2700 else 3600 end;
 elsif p_key in ('play2','play4','play6') then
  select count(*)::int into v from jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) x where x->>'s1' is not null and (x->>'p1'=p_player or x->>'p2'=p_player);
  target:=case p_key when 'play2' then 2 when 'play4' then 4 else 6 end;
  reward:=case p_key when 'play2' then 5000 when 'play4' then 7500 else 15000 end;
  xp_reward:=case p_key when 'play2' then 900 when 'play4' then 1500 else 2400 end;
 elsif p_key in ('diff5','diff10','diff15') then
  select coalesce(sum(case when x->>'p1'=p_player then (x->>'s1')::int-(x->>'s2')::int else (x->>'s2')::int-(x->>'s1')::int end),0)::int into v from jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) x where x->>'s1' is not null and (x->>'p1'=p_player or x->>'p2'=p_player);
  target:=case p_key when 'diff5' then 5 when 'diff10' then 10 else 15 end;
  reward:=case p_key when 'diff5' then 7500 when 'diff10' then 10000 else 17500 end;
  xp_reward:=case p_key when 'diff5' then 1800 when 'diff10' then 2700 else 3600 end;
 elsif p_key in ('c4wins2','c4wins4','c4wins6','c4wins8') then
  select count(*)::int into v from jsonb_array_elements(coalesce(d->'connect4','[]'::jsonb)) x where x->>'status'='done' and x->>'winner'=p_player and (coalesce((x->>'week')::int,-1)=wn or (x->>'week' is null and coalesce((x->>'createdAt')::bigint,0)>=challenge_start));
  target:=case p_key when 'c4wins2' then 2 when 'c4wins4' then 4 when 'c4wins6' then 6 else 8 end;
  reward:=case p_key when 'c4wins2' then 7500 when 'c4wins4' then 15000 when 'c4wins6' then 22000 else 30000 end;
  xp_reward:=case p_key when 'c4wins2' then 900 when 'c4wins4' then 1800 when 'c4wins6' then 2600 else 3600 end;
 elsif p_key in ('bswin1','bswin2','bswin3','bswin4') then
  select count(*)::int into v from jsonb_array_elements(coalesce(d->'battleships','[]'::jsonb)) x where x->>'status'='done' and x->>'winner'=p_player and (coalesce((x->>'week')::int,-1)=wn or (x->>'week' is null and coalesce((x->>'createdAt')::bigint,0)>=challenge_start));
  target:=case p_key when 'bswin1' then 1 when 'bswin2' then 2 when 'bswin3' then 3 else 4 end;
  reward:=case p_key when 'bswin1' then 7500 when 'bswin2' then 15000 when 'bswin3' then 22000 else 30000 end;
  xp_reward:=case p_key when 'bswin1' then 900 when 'bswin2' then 1800 when 'bswin3' then 2600 else 3600 end;
 elsif p_key in ('hogwin1','hogwin2','hogwin3','hogwin4') then
  select count(*)::int into v from jsonb_array_elements(coalesce(d->'hogDuels','[]'::jsonb)) x where x->>'status'='done' and x->>'winner'=p_player and coalesce((x->>'week')::int,-1)=wn;
  target:=case p_key when 'hogwin1' then 1 when 'hogwin2' then 2 when 'hogwin3' then 3 else 4 end;
  reward:=case p_key when 'hogwin1' then 5000 when 'hogwin2' then 10000 when 'hogwin3' then 15000 else 22000 end;
  xp_reward:=case p_key when 'hogwin1' then 700 when 'hogwin2' then 1400 when 'hogwin3' then 2100 else 3000 end;
 elsif p_key in ('chesswin1','chesswin2','chesswin3','chesswin4') then
  select count(*)::int into v from jsonb_array_elements(coalesce(d->'chess','[]'::jsonb)) x where x->>'status'='done' and x->>'winner'=p_player and coalesce((x->>'createdAt')::bigint,0)>=challenge_start;
  target:=case p_key when 'chesswin1' then 1 when 'chesswin2' then 2 when 'chesswin3' then 3 else 4 end;
  reward:=case p_key when 'chesswin1' then 7500 when 'chesswin2' then 15000 when 'chesswin3' then 22000 else 30000 end;
  xp_reward:=case p_key when 'chesswin1' then 900 when 'chesswin2' then 1800 when 'chesswin3' then 2600 else 3600 end;
 elsif p_key in ('pinplays3','pinplays5','pinplays7','pinplays10','pinscore50000','pinscore125000','pinscore200000','pinscore250000','pinscore300000','pinscore400000') then
  select count(*)::int into v from jsonb_array_elements(coalesce(d->'pinballScores','[]'::jsonb)) x
  where x->>'player'=p_player and coalesce((x->>'week')::int,-1)=wn and coalesce((x->>'at')::bigint,0)>=pinball_reset_at;
  if p_key like 'pinscore%' then
   select coalesce(max((x->>'score')::int),0)::int into v from jsonb_array_elements(coalesce(d->'pinballScores','[]'::jsonb)) x
   where x->>'player'=p_player and coalesce((x->>'week')::int,-1)=wn and coalesce((x->>'at')::bigint,0)>=pinball_reset_at;
   target:=case p_key
     when 'pinscore50000' then 15000
     when 'pinscore125000' then 40000
     when 'pinscore200000' then 60000
     when 'pinscore250000' then 90000
     when 'pinscore300000' then 300000
     else 400000 end;
  else target:=case p_key when 'pinplays3' then 3 when 'pinplays5' then 5 when 'pinplays7' then 7 else 10 end; end if;
  reward:=case p_key
    when 'pinplays3' then 10000 when 'pinplays5' then 20000
    when 'pinplays7' then 25000 when 'pinplays10' then 35000
    when 'pinscore50000' then 10000 when 'pinscore125000' then 17500
    when 'pinscore200000' then 25000 when 'pinscore250000' then 40000
    when 'pinscore300000' then 35000 else 50000 end;
  xp_reward:=case p_key
    when 'pinplays3' then 1400 when 'pinplays5' then 2600
    when 'pinplays7' then 3200 when 'pinplays10' then 4500
    when 'pinscore50000' then 1500 when 'pinscore125000' then 2500
    when 'pinscore200000' then 3500 when 'pinscore250000' then 5000
    when 'pinscore300000' then 4500 else 6500 end;
 elsif p_key in ('pred3','pred5','pred20','pred25') then
  select count(*)::int into v from jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) f where coalesce((d->'predictionRewards'->(f->>'id')->>p_player)::boolean,false);
  target:=case p_key when 'pred3' then 9 when 'pred5' then 15 when 'pred20' then 20 else 25 end;
  reward:=case p_key when 'pred3' then 10000 when 'pred5' then 20000 when 'pred20' then 27000 else 35000 end;
  xp_reward:=case p_key when 'pred3' then 1500 when 'pred5' then 3000 when 'pred20' then 3800 else 5000 end;
 elsif p_key in ('bokplay1','bokwin1','bokplay3','bokwin2') then
  select count(*)::int into v from jsonb_array_elements(coalesce(d->'bokemongs'->'battles','[]'::jsonb)) x
  where (x->>'a'=p_player or x->>'b'=p_player) and coalesce(nullif(x->>'completedAt','')::bigint,nullif(x->>'at','')::bigint,0)>=challenge_start and (x->>'winner' is not null) and (p_key in ('bokplay1','bokplay3') or x->>'winner'=p_player);
  target:=case p_key when 'bokplay1' then 1 when 'bokplay3' then 3 else 2 end;
  reward:=case p_key when 'bokplay1' then 10000 when 'bokplay3' then 22000 else 25000 end;
  xp_reward:=case p_key when 'bokplay1' then 1500 when 'bokplay3' then 3000 else 3500 end;
 elsif p_key in ('tdgames3','tdwave15','tdgames5','tdwave25') then
  if p_key in ('tdgames3','tdgames5') then
   select count(*)::int into v from jsonb_array_elements(coalesce(d->'towerDefenseScores','[]'::jsonb)) x where x->>'player'=p_player and coalesce((x->>'week')::int,-1)=wn and coalesce((x->>'at')::bigint,0)>=challenge_start;
   target:=case p_key when 'tdgames3' then 3 else 5 end;
   reward:=case p_key when 'tdgames3' then 10000 else 25000 end;
   xp_reward:=case p_key when 'tdgames3' then 1400 else 3500 end;
  else
   select coalesce(max((x->>'wave')::int),0)::int into v from jsonb_array_elements(coalesce(d->'towerDefenseScores','[]'::jsonb)) x where x->>'player'=p_player and coalesce((x->>'week')::int,-1)=wn and coalesce((x->>'at')::bigint,0)>=challenge_start;
   target:=case p_key when 'tdwave15' then 15 else 25 end;
   reward:=case p_key when 'tdwave15' then 15000 else 30000 end;
   xp_reward:=case p_key when 'tdwave15' then 2200 else 4200 end;
  end if;
 elsif p_key in ('spins2','spins5') then
  select count(*)::int into v from jsonb_array_elements(coalesce(d->'wheelSpinHistory','[]'::jsonb)) x where x->>'player'=p_player and coalesce((x->>'at')::bigint,0)>=challenge_start;
  target:=case p_key when 'spins2' then 20 else 50 end; reward:=case p_key when 'spins2' then 7500 else 15000 end; xp_reward:=case p_key when 'spins2' then 1000 else 2200 end;
 else return jsonb_build_object('active',false,'done',false,'week',wn);
 end if;
 return jsonb_build_object('active',true,'done',v>=target,'week',wn,'progress',v,'target',target,'reward',reward,'xp',xp_reward);
end
$function$;

CREATE OR REPLACE FUNCTION public.book_version()
RETURNS integer
LANGUAGE sql STABLE
SET search_path TO 'public','extensions'
AS $function$ SELECT 82; $function$;
