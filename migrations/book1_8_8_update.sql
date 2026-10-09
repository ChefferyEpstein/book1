-- Book1 1.8.8 database update (v30)
-- Dynamic correct-score pricing, prestige/challenge XP, minigame weekly challenges
-- and server-side betting locks at match start.
-- Safe to re-run.

begin;

create or replace function public.book_choose_188(p_n int, p_k int)
returns double precision
language plpgsql
immutable
as $function$
declare
  i int;
  k int;
  r double precision := 1;
begin
  if p_k < 0 or p_k > p_n then return 0; end if;
  k := least(p_k, p_n-p_k);
  if k = 0 then return 1; end if;
  for i in 1..k loop
    r := r * (p_n-k+i)::double precision / i::double precision;
  end loop;
  return r;
end
$function$;

create or replace function public.book_match_prob_188(d jsonb, a text, b text)
returns double precision
language plpgsql
stable
as $function$
declare
  ra double precision;
  rb double precision;
begin
  ra := public.book_rating(d,a);
  rb := public.book_rating(d,b);
  return ra*(1-rb)/(ra*(1-rb)+rb*(1-ra));
end
$function$;

create or replace function public.book_race8_win_prob_188(q double precision)
returns double precision
language plpgsql
immutable
as $function$
declare
  k int;
  p double precision := 0;
begin
  for k in 0..7 loop
    p := p + public.book_choose_188(7+k,k) * power(q,8) * power(1-q,k);
  end loop;
  return p;
end
$function$;

create or replace function public.book_point_prob_188(d jsonb, a text, b text)
returns double precision
language plpgsql
stable
as $function$
declare
  target double precision;
  lo double precision := 0.001;
  hi double precision := 0.999;
  mid double precision;
  i int;
begin
  target := public.book_match_prob_188(d,a,b);
  for i in 1..45 loop
    mid := (lo+hi)/2;
    if public.book_race8_win_prob_188(mid) < target then
      lo := mid;
    else
      hi := mid;
    end if;
  end loop;
  return (lo+hi)/2;
end
$function$;

create or replace function public.book_score_odds_188(d jsonb, a text, b text, p_s1 int, p_s2 int)
returns numeric
language plpgsql
stable
as $function$
declare
  q double precision;
  loser_score int;
  raw_p double precision;
  margin double precision;
  o double precision;
begin
  if greatest(p_s1,p_s2) <> 8
     or least(p_s1,p_s2) < 0
     or least(p_s1,p_s2) > 7
     or p_s1 = p_s2 then
    return 0;
  end if;

  q := public.book_point_prob_188(d,a,b);
  loser_score := least(p_s1,p_s2);

  if p_s1 = 8 then
    raw_p := public.book_choose_188(7+loser_score,loser_score)
      * power(q,8) * power(1-q,loser_score);
  else
    raw_p := public.book_choose_188(7+loser_score,loser_score)
      * power(1-q,8) * power(q,loser_score);
  end if;

  margin := coalesce((d->'payouts'->>'betMargin')::double precision,8)/100;
  o := (1/raw_p)*(1-margin);
  o := greatest(1.05,least(200,o));
  return (floor(o*100+0.5)/100)::numeric(8,2);
end
$function$;

create or replace function public.book_weekly_challenge_188(d jsonb, p_player text, p_key text)
returns jsonb
language plpgsql
stable
as $function$
declare
  w jsonb;
  wn int;
  idx int;
  core text[] := array['wins3','play4','diff10'];
  mini text[] := array['c4wins2','bswin1','hogwin1'];
  active1 text;
  active2 text;
  active3 text;
  v int := 0;
  reward int := 0;
  xp_reward int := 0;
  target int := 0;
  challenge_start bigint := 0;
begin
  if jsonb_array_length(coalesce(d->'weeks','[]'::jsonb)) = 0 then
    return jsonb_build_object('active',false,'done',false);
  end if;

  w := d->'weeks'->(jsonb_array_length(d->'weeks')-1);
  wn := (w->>'n')::int;
  idx := ((wn-1) % 3)+1;
  active1 := core[idx];
  active2 := mini[idx];
  active3 := core[(idx % 3)+1];

  if p_key <> all(array[active1,active2,active3]) then
    return jsonb_build_object('active',false,'done',false,'week',wn);
  end if;

  if p_key = 'wins3' then
    select count(*)::int into v
    from jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) x
    where x->>'s1' is not null
      and (((x->>'s1')::int>(x->>'s2')::int and x->>'p1'=p_player)
        or ((x->>'s2')::int>(x->>'s1')::int and x->>'p2'=p_player));
    reward := 10000; xp_reward := 750; target := 3;

  elsif p_key = 'play4' then
    select count(*)::int into v
    from jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) x
    where x->>'s1' is not null and (x->>'p1'=p_player or x->>'p2'=p_player);
    reward := 5000; xp_reward := 400; target := 4;

  elsif p_key = 'diff10' then
    select coalesce(sum(case
      when x->>'p1'=p_player then (x->>'s1')::int-(x->>'s2')::int
      else (x->>'s2')::int-(x->>'s1')::int end),0)::int into v
    from jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) x
    where x->>'s1' is not null and (x->>'p1'=p_player or x->>'p2'=p_player);
    reward := 7500; xp_reward := 750; target := 10;

  elsif p_key = 'c4wins2' then
    challenge_start := coalesce((d->>'challengeWeekStartedAt')::bigint,0);
    select count(*)::int into v
    from jsonb_array_elements(coalesce(d->'connect4','[]'::jsonb)) x
    where x->>'status'='done' and x->>'winner'=p_player
      and (
        coalesce((x->>'week')::int,-1)=wn
        or (x->>'week' is null and coalesce((x->>'createdAt')::bigint,0)>=challenge_start)
      );
    reward := 5000; xp_reward := 500; target := 2;

  elsif p_key = 'bswin1' then
    challenge_start := coalesce((d->>'challengeWeekStartedAt')::bigint,0);
    select count(*)::int into v
    from jsonb_array_elements(coalesce(d->'battleships','[]'::jsonb)) x
    where x->>'status'='done' and x->>'winner'=p_player
      and (
        coalesce((x->>'week')::int,-1)=wn
        or (x->>'week' is null and coalesce((x->>'createdAt')::bigint,0)>=challenge_start)
      );
    reward := 5000; xp_reward := 500; target := 1;

  elsif p_key = 'hogwin1' then
    select count(*)::int into v
    from jsonb_array_elements(coalesce(d->'hogDuels','[]'::jsonb)) x
    where x->>'status'='done' and x->>'winner'=p_player and coalesce((x->>'week')::int,-1)=wn;
    reward := 3000; xp_reward := 300; target := 1;
  end if;

  return jsonb_build_object(
    'active',true,
    'done',v>=target,
    'week',wn,
    'progress',v,
    'target',target,
    'reward',reward,
    'xp',xp_reward
  );
end
$function$;

create or replace function public.book_player_xp(p_data jsonb, p_player text)
returns integer
language plpgsql
stable
as $function$
declare
  w jsonb;
  g jsonb;
  xp integer := 0;
  gd integer;
begin
  for w in select value from jsonb_array_elements(coalesce(p_data->'weeks','[]'::jsonb))
  loop
    for g in select value from jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb))
    loop
      if g->>'s1' is null or (g->>'p1' <> p_player and g->>'p2' <> p_player) then
        continue;
      end if;
      xp := xp + 100;
      if ((g->>'s1')::int > (g->>'s2')::int and g->>'p1' = p_player)
         or ((g->>'s2')::int > (g->>'s1')::int and g->>'p2' = p_player) then
        xp := xp + 200;
      end if;
      gd := case when g->>'p1' = p_player
        then (g->>'s1')::int - (g->>'s2')::int
        else (g->>'s2')::int - (g->>'s1')::int end;
      if gd > 0 then xp := xp + gd * 10; end if;
    end loop;
  end loop;

  for g in select value from jsonb_array_elements(coalesce(p_data->'connect4','[]'::jsonb))
  loop
    if g->>'status' in ('done','draw') and (g->>'challenger' = p_player or g->>'opponent' = p_player) then
      xp := xp + 50;
      if g->>'winner' = p_player then xp := xp + 100; end if;
    end if;
  end loop;

  for g in select value from jsonb_array_elements(coalesce(p_data->'battleships','[]'::jsonb))
  loop
    if g->>'status' = 'done' and (g->>'challenger' = p_player or g->>'opponent' = p_player) then
      xp := xp + 50;
      if g->>'winner' = p_player then xp := xp + 100; end if;
    end if;
  end loop;

  for g in select value from jsonb_array_elements(coalesce(p_data->'hogDuels','[]'::jsonb))
  loop
    if g->>'status' = 'done' and (g->>'challenger' = p_player or g->>'opponent' = p_player) then
      xp := xp + 25;
      if g->>'winner' = p_player then xp := xp + 50; end if;
    end if;
  end loop;

  select coalesce(sum(coalesce((x->>'xp')::int,0)),0)::int into gd
  from jsonb_array_elements(coalesce(p_data->'challengeClaims','[]'::jsonb)) x
  where x->>'player'=p_player;
  xp := xp + gd;

  return xp;
end
$function$;

update public.book
set data = jsonb_set(
      jsonb_set(data,'{bettingLocks}',coalesce(data->'bettingLocks','{}'::jsonb),true),
      '{challengeWeekStartedAt}',
      coalesce(data->'challengeWeekStartedAt',to_jsonb((extract(epoch from now())*1000)::bigint)),
      true
    ),
    version = version + 1,
    updated_at = now()
where id=1
  and (not (data ? 'bettingLocks') or not (data ? 'challengeWeekStartedAt'));

do $$
declare
  f text;
  p1 int;
  p2 int;
  start_block text := $b$
elsif t = 'startMatch' then
    g := public.book_find_game_187(d,p_action->>'id');
    if g is null then raise exception 'That match no longer exists.'; end if;
    if g->>'p1' <> p_name and g->>'p2' <> p_name then raise exception 'Only the two players can start this match.'; end if;
    if g->>'s1' is not null then raise exception 'That match is already finished.'; end if;
    d := jsonb_set(d,'{bettingLocks}',coalesce(d->'bettingLocks','{}'::jsonb),true);
    if (d->'bettingLocks') ? (p_action->>'id') then raise exception 'Betting is already closed for that match.'; end if;
    d := jsonb_set(d,array['bettingLocks',p_action->>'id'],jsonb_build_object(
      'startedAt',(extract(epoch from now())*1000)::bigint,
      'startedBy',p_name
    ),true);
    d := jsonb_set(d,'{log}',(d->'log') || to_jsonb(stamp || ' ' || p_name || ' started ' || (g->>'p1') || ' v ' || (g->>'p2') || '; betting closed'));

  $b$;
  score_block text := $b$
elsif t = 'placeScoreBet' then
    g := public.book_find_game_187(d,p_action->>'game');
    if g is null or g->>'p1' is null or g->>'p2' is null then raise exception 'That match no longer exists.'; end if;
    if g->>'s1' is not null or g->>'status' <> 'open' or (coalesce(d->'bettingLocks','{}'::jsonb) ? (g->>'id')) then raise exception 'Betting is closed on that match.'; end if;
    if p_name = g->>'p1' or p_name = g->>'p2' then raise exception 'You cannot bet on your own match.'; end if;

    s1 := floor((p_action->>'s1')::numeric)::int;
    s2 := floor((p_action->>'s2')::numeric)::int;
    bodds := public.book_score_odds_188(d,g->>'p1',g->>'p2',s1,s2);
    if bodds <= 0 then raise exception 'Pick a valid race-to-8 score.'; end if;
    wi := floor((p_action->>'stake')::numeric)::int;
    if wi is null or wi < 1 then raise exception 'Bad stake.'; end if;
    if wi + coalesce((
      select sum((x->>'stake')::int)
      from jsonb_array_elements(coalesce(d->'scoreBets','[]'::jsonb)) x
      where x->>'player'=p_name and x->>'game'=g->>'id' and x->>'status'='open'
    ),0) > coalesce((d->'payouts'->>'casinoMaxBet')::int,500) then
      raise exception 'Correct-score stake exceeds the match cap.';
    end if;
    if wi > coalesce((d->'chips'->>p_name)::int,1000) then raise exception 'You cannot bet more than your chip balance.'; end if;

    d := jsonb_set(d,'{scoreBets}',coalesce(d->'scoreBets','[]'::jsonb),true);
    d := jsonb_set(d,'{chips}',coalesce(d->'chips','{}'::jsonb),true);
    d := jsonb_set(d,array['chips',p_name],to_jsonb(coalesce((d->'chips'->>p_name)::int,1000)-wi),true);
    bid := 'sb' || ((extract(epoch from clock_timestamp())*1000)::bigint)::text;
    d := jsonb_set(d,'{scoreBets}',(d->'scoreBets') || jsonb_build_array(jsonb_build_object(
      'id',bid,'player',p_name,'game',g->>'id','label',(g->>'p1')||' v '||(g->>'p2'),
      's1',s1,'s2',s2,'stake',wi,'odds',bodds,
      'status','open','payout',0,'placedAt',(extract(epoch from now())*1000)::bigint
    )));
    d := jsonb_set(d,'{log}',(d->'log') || to_jsonb(format('%s bet %s chips on %s %s-%s %s at %s',p_name,wi,g->>'p1',s1,s2,g->>'p2',bodds)));

  $b$;
  claim_block text := $b$
elsif t = 'claimWeekly' then
    w := d->'weeks'->(jsonb_array_length(d->'weeks')-1);
    if exists (
      select 1 from jsonb_array_elements(coalesce(d->'challengeClaims','[]'::jsonb)) x
      where (x->>'week')::int=(w->>'n')::int and x->>'player'=p_name and x->>'key'=p_action->>'key'
    ) then raise exception 'Already claimed.'; end if;

    g := public.book_weekly_challenge_188(d,p_name,p_action->>'key');
    if not coalesce((g->>'active')::boolean,false) then raise exception 'That challenge is not active this week.'; end if;
    if not coalesce((g->>'done')::boolean,false) then raise exception 'Challenge is not complete yet.'; end if;

    wi := (g->>'reward')::int;
    s1 := (g->>'xp')::int;
    d := jsonb_set(d,'{challengeClaims}',coalesce(d->'challengeClaims','[]'::jsonb),true);
    d := jsonb_set(d,'{chips}',coalesce(d->'chips','{}'::jsonb),true);
    d := jsonb_set(d,array['chips',p_name],to_jsonb(coalesce((d->'chips'->>p_name)::int,1000)+wi),true);
    d := jsonb_set(d,'{challengeClaims}',(d->'challengeClaims') || jsonb_build_array(jsonb_build_object(
      'week',(w->>'n')::int,'player',p_name,'key',p_action->>'key','reward',wi,'xp',s1,'at',(extract(epoch from now())*1000)::bigint
    )));
    d := jsonb_set(d,'{log}',(d->'log') || to_jsonb(format('%s claimed %s chips and %s XP for weekly challenge %s',p_name,wi,s1,p_action->>'key')));

  $b$;
begin
  select pg_get_functiondef('public.book_player_action(text,text,jsonb)'::regprocedure) into f;

  if position('elsif t = ''startMatch'' then' in f)=0 then
    p1 := position('elsif t = ''placeScoreBet'' then' in f);
    if p1=0 then raise exception 'Book1 1.8.8 migration stopped: placeScoreBet anchor missing.'; end if;
    f := substring(f from 1 for p1-1) || start_block || substring(f from p1);
  end if;

  if position('Start the match first. That closes betting before play begins.' in f)=0 then
    if position('elsif t = ''submit'' then' in f)=0 then raise exception 'Book1 1.8.8 migration stopped: submit anchor missing.'; end if;
    f := replace(
      f,
      'elsif t = ''submit'' then',
      'elsif t = ''submit'' then' || E'\n    if not (coalesce(d->''bettingLocks'',''{}''::jsonb) ? (p_action->>''id'')) then raise exception ''Start the match first. That closes betting before play begins.''; end if;'
    );
  end if;

  f := replace(
    f,
    'if (g->>''s1'') is not null or coalesce(g->>''status'',''open'') <> ''open'' then raise exception ''Betting is closed on that match.''; end if;',
    'if (g->>''s1'') is not null or coalesce(g->>''status'',''open'') <> ''open'' or (coalesce(d->''bettingLocks'',''{}''::jsonb) ? (g->>''id'')) then raise exception ''Betting is closed on that match.''; end if;'
  );

  f := replace(
    f,
    'if (g->>''s1'') is not null or coalesce(g->>''status'',''open'') <> ''open'' then raise exception ''Betting has closed on %.'', (g->>''p1'') || '' v '' || (g->>''p2''); end if;',
    'if (g->>''s1'') is not null or coalesce(g->>''status'',''open'') <> ''open'' or (coalesce(d->''bettingLocks'',''{}''::jsonb) ? (g->>''id'')) then raise exception ''Betting has closed on %.'', (g->>''p1'') || '' v '' || (g->>''p2''); end if;'
  );

  if position('Cash out is closed because a remaining leg has started.' in f)=0 then
    f := replace(
      f,
      'if not any_won then raise exception ''Nothing has won yet on this accumulator.''; end if;',
      'if not any_won then raise exception ''Nothing has won yet on this accumulator.''; end if;' || E'\n    if exists (select 1 from jsonb_array_elements(bet->''legs'') z where z->>''status''=''open'' and (coalesce(d->''bettingLocks'',''{}''::jsonb) ? (z->>''game''))) then raise exception ''Cash out is closed because a remaining leg has started.''; end if;'
    );
  end if;

  p1 := position('elsif t = ''placeScoreBet'' then' in f);
  p2 := position('elsif t = ''claimWeekly'' then' in f);
  if p1=0 or p2=0 or p2<=p1 then raise exception 'Book1 1.8.8 migration stopped: score/claim anchors missing.'; end if;
  f := substring(f from 1 for p1-1) || score_block || substring(f from p2);

  p1 := position('elsif t = ''claimWeekly'' then' in f);
  p2 := position('elsif t = ''prestige'' then' in f);
  if p1=0 or p2=0 or p2<=p1 then raise exception 'Book1 1.8.8 migration stopped: claim/prestige anchors missing.'; end if;
  f := substring(f from 1 for p1-1) || claim_block || substring(f from p2);

  f := replace(
    f,
    'if g->>''s1'' is not null or g->>''status'' <> ''open'' then raise exception ''That match has already started reporting or finished.''; end if;',
    'if g->>''s1'' is not null or g->>''status'' <> ''open'' or (coalesce(d->''bettingLocks'',''{}''::jsonb) ? (g->>''id'')) then raise exception ''That match has started or finished; bounty market closed.''; end if;'
  );

  f := replace(
    f,
    'where x->>''id''=g->>''game'' and x->>''status'' <> ''open''',
    'where x->>''id''=g->>''game'' and (x->>''status'' <> ''open'' or (coalesce(d->''bettingLocks'',''{}''::jsonb) ? (x->>''id'')))'
  );

  execute f;
end
$$;

create or replace function public.book_version()
returns integer
language sql
as $function$
  select 30
$function$;

commit;

-- Verification: expect all true / version 30.
select
  public.book_version() as database_function_version,
  position('elsif t = ''startMatch'' then' in pg_get_functiondef('public.book_player_action(text,text,jsonb)'::regprocedure)) > 0 as start_match_installed,
  position('book_score_odds_188' in pg_get_functiondef('public.book_player_action(text,text,jsonb)'::regprocedure)) > 0 as dynamic_score_odds_installed,
  position('Cash out is closed because a remaining leg has started.' in pg_get_functiondef('public.book_player_action(text,text,jsonb)'::regprocedure)) > 0 as cashout_lock_installed,
  position('book_weekly_challenge_188' in pg_get_functiondef('public.book_player_action(text,text,jsonb)'::regprocedure)) > 0 as weekly_xp_challenges_installed,
  (select data ? 'bettingLocks' and data ? 'challengeWeekStartedAt' from public.book where id=1) as lock_state_ready;
