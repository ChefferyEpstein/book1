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

  if p_key in ('wins3','wins5','wins8') then
    select count(*)::int into v from jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) x
    where x->>'s1' is not null and
      (((x->>'s1')::int>(x->>'s2')::int and x->>'p1'=p_player) or
       ((x->>'s2')::int>(x->>'s1')::int and x->>'p2'=p_player));
    target:=case p_key when 'wins3' then 3 when 'wins5' then 5 else 8 end;
    reward:=case p_key when 'wins3' then 10000 when 'wins5' then 15000 else 25000 end;
    xp_reward:=case p_key when 'wins3' then 1500 when 'wins5' then 2250 else 3500 end;
  elsif p_key in ('play4','play8','play12') then
    select count(*)::int into v from jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) x
    where x->>'s1' is not null and (x->>'p1'=p_player or x->>'p2'=p_player);
    target:=case p_key when 'play4' then 4 when 'play8' then 8 else 12 end;
    reward:=case p_key when 'play4' then 7500 when 'play8' then 12500 else 20000 end;
    xp_reward:=case p_key when 'play4' then 1200 when 'play8' then 2000 else 3000 end;
  elsif p_key in ('diff10','diff20','diff30') then
    select coalesce(sum(case when x->>'p1'=p_player then (x->>'s1')::int-(x->>'s2')::int else (x->>'s2')::int-(x->>'s1')::int end),0)::int into v
    from jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) x
    where x->>'s1' is not null and (x->>'p1'=p_player or x->>'p2'=p_player);
    target:=case p_key when 'diff10' then 10 when 'diff20' then 20 else 30 end;
    reward:=case p_key when 'diff10' then 10000 when 'diff20' then 17500 else 25000 end;
    xp_reward:=case p_key when 'diff10' then 1500 when 'diff20' then 2500 else 3500 end;
  elsif p_key in ('c4wins2','c4wins4') then
    select count(*)::int into v from jsonb_array_elements(coalesce(d->'connect4','[]'::jsonb)) x
    where x->>'status'='done' and x->>'winner'=p_player
      and (coalesce((x->>'week')::int,-1)=wn or (x->>'week' is null and coalesce((x->>'createdAt')::bigint,0)>=challenge_start));
    target:=case p_key when 'c4wins2' then 2 else 4 end;
    reward:=case p_key when 'c4wins2' then 7500 else 15000 end;
    xp_reward:=case p_key when 'c4wins2' then 1000 else 2000 end;
  elsif p_key in ('bswin1','bswin2') then
    select count(*)::int into v from jsonb_array_elements(coalesce(d->'battleships','[]'::jsonb)) x
    where x->>'status'='done' and x->>'winner'=p_player
      and (coalesce((x->>'week')::int,-1)=wn or (x->>'week' is null and coalesce((x->>'createdAt')::bigint,0)>=challenge_start));
    target:=case p_key when 'bswin1' then 1 else 2 end;
    reward:=case p_key when 'bswin1' then 7500 else 15000 end;
    xp_reward:=case p_key when 'bswin1' then 1000 else 2000 end;
  elsif p_key in ('hogwin1','hogwin2') then
    select count(*)::int into v from jsonb_array_elements(coalesce(d->'hogDuels','[]'::jsonb)) x
    where x->>'status'='done' and x->>'winner'=p_player and coalesce((x->>'week')::int,-1)=wn;
    target:=case p_key when 'hogwin1' then 1 else 2 end;
    reward:=case p_key when 'hogwin1' then 5000 else 10000 end;
    xp_reward:=case p_key when 'hogwin1' then 800 else 1600 end;
  elsif p_key in ('chesswin1','chesswin2') then
    select count(*)::int into v from jsonb_array_elements(coalesce(d->'chess','[]'::jsonb)) x
    where x->>'status'='done' and x->>'winner'=p_player
      and coalesce((x->>'createdAt')::bigint,0)>=challenge_start;
    target:=case p_key when 'chesswin1' then 1 else 2 end;
    reward:=case p_key when 'chesswin1' then 7500 else 15000 end;
    xp_reward:=case p_key when 'chesswin1' then 1000 else 2000 end;
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
    xp_reward:=case p_key when 'pinplays1' then 800 when 'pinplays3' then 1600 when 'pinscore1000' then 1200 else 2500 end;
  else
    return jsonb_build_object('active',false,'done',false,'week',wn);
  end if;
  return jsonb_build_object('active',true,'done',v>=target,'week',wn,'progress',v,'target',target,'reward',reward,'xp',xp_reward);
end
$function$


CREATE OR REPLACE FUNCTION public.book_pinball_start(p_name text, p_pin text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare d jsonb; v int; balance int; token text; wn int;
begin
  if public.book_check(p_name,p_pin) is null then raise exception 'Wrong name or PIN'; end if;
  select data,version into d,v from public.book where id=1 for update;
  balance:=coalesce((d->'chips'->>p_name)::int,1000);
  if balance<100 then raise exception 'You need 100 chips to play Pinball.'; end if;
  if exists(select 1 from jsonb_array_elements(coalesce(d->'pinballSessions','[]'::jsonb)) x where x->>'player'=p_name and x->>'status'='playing') then
    raise exception 'You already have a Pinball game in progress.';
  end if;
  wn:=(d->'weeks'->(jsonb_array_length(d->'weeks')-1)->>'n')::int;
  token:=md5(random()::text||clock_timestamp()::text||p_name);
  d:=jsonb_set(d,'{chips}',coalesce(d->'chips','{}'::jsonb),true);
  d:=jsonb_set(d,array['chips',p_name],to_jsonb(balance-100),true);
  d:=jsonb_set(d,'{pinballSessions}',coalesce(d->'pinballSessions','[]'::jsonb)||jsonb_build_array(jsonb_build_object(
    'token',token,'player',p_name,'status','playing','week',wn,
    'startedAt',(extract(epoch from clock_timestamp())*1000)::bigint
  )),true);
  d:=jsonb_set(d,'{log}',coalesce(d->'log','[]'::jsonb)||to_jsonb(format('%s paid 100 chips to play Pinball',p_name)),true);
  update public.book set data=d,version=v+1,updated_at=now() where id=1;
  return jsonb_build_object('token',token,'version',v+1);
end
$function$


CREATE OR REPLACE FUNCTION public.book_pinball_finish(p_name text, p_pin text, p_token text, p_score integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare d jsonb; v int; i int; sess jsonb; elapsed bigint; prize int; balance int; rec jsonb; wn int;
begin
  if public.book_check(p_name,p_pin) is null then raise exception 'Wrong name or PIN'; end if;
  if p_score is null or p_score<0 or p_score>8000 then raise exception 'Invalid Pinball score.'; end if;
  select data,version into d,v from public.book where id=1 for update;
  i:=null;
  for rec in select value from jsonb_array_elements(coalesce(d->'pinballSessions','[]'::jsonb)) with ordinality as x(value,ord) loop
    if rec->>'token'=p_token and rec->>'player'=p_name and rec->>'status'='playing' then
      i:=(select ord::int-1 from jsonb_array_elements(coalesce(d->'pinballSessions','[]'::jsonb)) with ordinality as z(value,ord) where value=rec limit 1);
      sess:=rec;
      exit;
    end if;
  end loop;
  if i is null or sess is null then raise exception 'That Pinball game has already finished or is invalid.'; end if;
  elapsed:=(extract(epoch from clock_timestamp())*1000)::bigint-(sess->>'startedAt')::bigint;
  if elapsed<15000 then raise exception 'Play for at least 15 seconds before submitting a score.'; end if;
  if p_score>greatest(250,floor((elapsed::numeric/1000)*180)::int) then raise exception 'That score is too high for the time played.'; end if;
  prize:=case when p_score<500 then 0 when p_score<1000 then 50 when p_score<2000 then 125 when p_score<3500 then 250 when p_score<5000 then 500 else 1000 end;
  balance:=coalesce((d->'chips'->>p_name)::int,1000);
  wn:=(sess->>'week')::int;
  d:=jsonb_set(d,array['pinballSessions',i::text],sess||jsonb_build_object('status','finished','score',p_score,'prize',prize,'finishedAt',(extract(epoch from clock_timestamp())*1000)::bigint),true);
  d:=jsonb_set(d,'{chips}',coalesce(d->'chips','{}'::jsonb),true);
  d:=jsonb_set(d,array['chips',p_name],to_jsonb(balance+prize),true);
  d:=jsonb_set(d,'{pinballScores}',coalesce(d->'pinballScores','[]'::jsonb)||jsonb_build_array(jsonb_build_object(
    'player',p_name,'score',p_score,'prize',prize,'week',wn,'at',(extract(epoch from clock_timestamp())*1000)::bigint
  )),true);
  d:=jsonb_set(d,'{log}',coalesce(d->'log','[]'::jsonb)||to_jsonb(format('%s scored %s on Pinball and won %s chips',p_name,p_score,prize)),true);
  update public.book set data=d,version=v+1,updated_at=now() where id=1;
  return jsonb_build_object('score',p_score,'prize',prize,'balance',balance+prize,'version',v+1);
end
$function$


revoke all on function public.book_pinball_start(text,text) from public;
grant execute on function public.book_pinball_start(text,text) to anon, authenticated;
revoke all on function public.book_pinball_finish(text,text,text,integer) from public;
grant execute on function public.book_pinball_finish(text,text,text,integer) to anon, authenticated;