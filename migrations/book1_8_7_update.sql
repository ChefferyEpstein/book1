-- Book1 1.8.7 database update (v29)
-- Features:
--   - Correct-score pool betting
--   - XP / levels / prestige
--   - Weekly chip challenges
--   - Pool bounties
--   - Fantasy game-week teams
--   - Battleships ship-separation validation
-- Safe to re-run.

begin;

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

  return xp;
end
$function$;

create or replace function public.book_fantasy_tiers(p_data jsonb)
returns jsonb
language sql
stable
as $function$
  with active as (
    select p->>'name' as name
    from jsonb_array_elements(coalesce(p_data->'players','[]'::jsonb)) p
    where coalesce((p->>'active')::boolean,false)
  ),
  games as (
    select g
    from jsonb_array_elements(coalesce(p_data->'weeks','[]'::jsonb)) w
    cross join lateral jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) g
    where g->>'s1' is not null
  ),
  stats as (
    select
      a.name,
      count(*) filter (
        where ((g->>'s1')::int > (g->>'s2')::int and g->>'p1'=a.name)
           or ((g->>'s2')::int > (g->>'s1')::int and g->>'p2'=a.name)
      )::int as wins,
      coalesce(sum(
        case
          when g->>'p1'=a.name then (g->>'s1')::int-(g->>'s2')::int
          when g->>'p2'=a.name then (g->>'s2')::int-(g->>'s1')::int
          else 0
        end
      ),0)::int as diff
    from active a
    left join games g on g->>'p1'=a.name or g->>'p2'=a.name
    group by a.name
  ),
  ranked as (
    select name, row_number() over(order by wins desc,diff desc,name asc) as rn
    from stats
  )
  select jsonb_build_object(
    'elite', coalesce(jsonb_agg(name order by rn) filter(where rn between 1 and 4),'[]'::jsonb),
    'challenger', coalesce(jsonb_agg(name order by rn) filter(where rn between 5 and 8),'[]'::jsonb),
    'mongs', coalesce(jsonb_agg(name order by rn) filter(where rn >= 9),'[]'::jsonb)
  )
  from ranked
$function$;

create or replace function public.book_bs_separated_ships(p_ships jsonb)
returns boolean
language plpgsql
immutable
as $function$
declare
  a jsonb;
  b jsonb;
  ca jsonb;
  cb jsonb;
begin
  if jsonb_typeof(p_ships) <> 'array' then return false; end if;
  for a in select value from jsonb_array_elements(p_ships)
  loop
    for b in select value from jsonb_array_elements(p_ships)
    loop
      if a->>'id' = b->>'id' then continue; end if;
      for ca in select value from jsonb_array_elements(coalesce(a->'cells','[]'::jsonb))
      loop
        for cb in select value from jsonb_array_elements(coalesce(b->'cells','[]'::jsonb))
        loop
          if abs((ca->>0)::int-(cb->>0)::int) <= 1
             and abs((ca->>1)::int-(cb->>1)::int) <= 1 then
            return false;
          end if;
        end loop;
      end loop;
    end loop;
  end loop;
  return true;
end
$function$;

create or replace function public.book_settle_187(p_data jsonb)
returns jsonb
language plpgsql
as $function$
declare
  idx integer;
  b jsonb;
  g jsonb;
  stake integer;
  pay integer;
  cur integer;
  odds numeric;
  winner_name text;
begin
  p_data := jsonb_set(p_data,'{chips}',coalesce(p_data->'chips','{}'::jsonb),true);
  p_data := jsonb_set(p_data,'{scoreBets}',coalesce(p_data->'scoreBets','[]'::jsonb),true);
  p_data := jsonb_set(p_data,'{bounties}',coalesce(p_data->'bounties','[]'::jsonb),true);

  if jsonb_array_length(p_data->'scoreBets') > 0 then
    for idx in 0..jsonb_array_length(p_data->'scoreBets')-1
    loop
      b := p_data->'scoreBets'->idx;
      if b->>'status' <> 'open' then continue; end if;

      g := null;
      select gg into g
      from jsonb_array_elements(coalesce(p_data->'weeks','[]'::jsonb)) ww
      cross join lateral jsonb_array_elements(coalesce(ww->'fixtures','[]'::jsonb)) gg
      where gg->>'id' = b->>'game'
      limit 1;

      stake := coalesce((b->>'stake')::int,0);
      if g is null then
        cur := coalesce((p_data->'chips'->>(b->>'player'))::int,1000);
        p_data := jsonb_set(p_data,array['chips',b->>'player'],to_jsonb(cur+stake),true);
        b := b || jsonb_build_object('status','void','payout',stake);
        p_data := jsonb_set(p_data,array['scoreBets',idx::text],b,true);
        continue;
      end if;

      if g->>'s1' is null then continue; end if;
      if (g->>'s1')::int = (b->>'s1')::int and (g->>'s2')::int = (b->>'s2')::int then
        odds := coalesce((b->>'odds')::numeric,1);
        pay := round(stake * odds)::int;
        cur := coalesce((p_data->'chips'->>(b->>'player'))::int,1000);
        p_data := jsonb_set(p_data,array['chips',b->>'player'],to_jsonb(cur+pay),true);
        b := b || jsonb_build_object('status','won','payout',pay);
      else
        b := b || jsonb_build_object('status','lost','payout',0);
      end if;
      p_data := jsonb_set(p_data,array['scoreBets',idx::text],b,true);
    end loop;
  end if;

  if jsonb_array_length(p_data->'bounties') > 0 then
    for idx in 0..jsonb_array_length(p_data->'bounties')-1
    loop
      b := p_data->'bounties'->idx;
      if b->>'status' <> 'open' then continue; end if;

      g := null;
      select gg into g
      from jsonb_array_elements(coalesce(p_data->'weeks','[]'::jsonb)) ww
      cross join lateral jsonb_array_elements(coalesce(ww->'fixtures','[]'::jsonb)) gg
      where gg->>'id' = b->>'game'
      limit 1;

      stake := coalesce((b->>'amount')::int,0);
      if g is null then
        cur := coalesce((p_data->'chips'->>(b->>'sponsor'))::int,1000);
        p_data := jsonb_set(p_data,array['chips',b->>'sponsor'],to_jsonb(cur+stake),true);
        b := b || jsonb_build_object('status','void');
        p_data := jsonb_set(p_data,array['bounties',idx::text],b,true);
        continue;
      end if;

      if g->>'s1' is null then continue; end if;
      winner_name := case when (g->>'s1')::int > (g->>'s2')::int then g->>'p1' else g->>'p2' end;
      if winner_name = b->>'hunter' then
        cur := coalesce((p_data->'chips'->>(b->>'hunter'))::int,1000);
        p_data := jsonb_set(p_data,array['chips',b->>'hunter'],to_jsonb(cur+stake),true);
        b := b || jsonb_build_object('status','claimed','claimedBy',b->>'hunter');
      else
        cur := coalesce((p_data->'chips'->>(b->>'sponsor'))::int,1000);
        p_data := jsonb_set(p_data,array['chips',b->>'sponsor'],to_jsonb(cur+stake),true);
        b := b || jsonb_build_object('status','failed');
      end if;
      p_data := jsonb_set(p_data,array['bounties',idx::text],b,true);
    end loop;
  end if;

  return p_data;
end
$function$;

-- Initialise the new top-level collections without disturbing existing data.
update public.book
set
  data = data || jsonb_build_object(
    'scoreBets', coalesce(data->'scoreBets','[]'::jsonb),
    'progression', coalesce(data->'progression','{}'::jsonb),
    'challengeClaims', coalesce(data->'challengeClaims','[]'::jsonb),
    'fantasyWeeks', coalesce(data->'fantasyWeeks','{}'::jsonb),
    'bounties', coalesce(data->'bounties','[]'::jsonb),
    'payouts', coalesce(data->'payouts','{}'::jsonb) || jsonb_build_object(
      'fantasyPrize', coalesce((data->'payouts'->>'fantasyPrize')::int,50000)
    )
  ),
  version = version + 1,
  updated_at = now()
where id = 1;

-- Snapshot current Master tiers for the live fantasy week if this week has no snapshot yet.
do $$
declare
  d jsonb;
  wk text;
begin
  select data into d from public.book where id=1 for update;
  if jsonb_array_length(coalesce(d->'weeks','[]'::jsonb)) > 0 then
    wk := d->'weeks'->(jsonb_array_length(d->'weeks')-1)->>'n';
    if not (coalesce(d->'fantasyWeeks','{}'::jsonb) ? wk) then
      d := jsonb_set(
        d,
        array['fantasyWeeks',wk],
        jsonb_build_object('tiers',public.book_fantasy_tiers(d),'picks','{}'::jsonb,'paid',false),
        true
      );
      update public.book set data=d,version=version+1,updated_at=now() where id=1;
    end if;
  end if;
end
$$;

-- Extend the player RPC with the new player-owned actions and settlement hook.
do $$
declare
  f text;
  actions text := $actions$
  elsif t = 'placeScoreBet' then
    w := d->'weeks'->(jsonb_array_length(d->'weeks')-1);
    g := null;
    select value into g
    from jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb))
    where value->>'id' = p_action->>'game'
    limit 1;
    if g is null or g->>'p1' is null or g->>'p2' is null then raise exception 'That match no longer exists.'; end if;
    if g->>'s1' is not null or g->>'status' <> 'open' then raise exception 'Betting is closed on that match.'; end if;
    if p_name = g->>'p1' or p_name = g->>'p2' then raise exception 'You cannot bet on your own match.'; end if;

    s1 := floor((p_action->>'s1')::numeric)::int;
    s2 := floor((p_action->>'s2')::numeric)::int;
    if greatest(s1,s2) <> 8 or least(s1,s2) < 0 or least(s1,s2) > 7 or s1=s2 then raise exception 'Pick a valid race-to-8 score.'; end if;
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
      's1',s1,'s2',s2,'stake',wi,
      'odds',case least(s1,s2) when 0 then 20 when 1 then 16 when 2 then 13 when 3 then 11 when 4 then 9 when 5 then 8 when 6 then 7 else 6 end,
      'status','open','payout',0,'placedAt',(extract(epoch from now())*1000)::bigint
    )));

  elsif t = 'claimWeekly' then
    w := d->'weeks'->(jsonb_array_length(d->'weeks')-1);
    if p_action->>'key' not in ('wins3','play4','diff10') then raise exception 'Unknown challenge.'; end if;
    if exists (
      select 1 from jsonb_array_elements(coalesce(d->'challengeClaims','[]'::jsonb)) x
      where (x->>'week')::int=(w->>'n')::int and x->>'player'=p_name and x->>'key'=p_action->>'key'
    ) then raise exception 'Already claimed.'; end if;

    select count(*)::int into s1
    from jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) x
    where x->>'s1' is not null and (x->>'p1'=p_name or x->>'p2'=p_name);

    select count(*)::int into s2
    from jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) x
    where x->>'s1' is not null
      and (((x->>'s1')::int>(x->>'s2')::int and x->>'p1'=p_name)
        or ((x->>'s2')::int>(x->>'s1')::int and x->>'p2'=p_name));

    if p_action->>'key'='wins3' then
      if s2 < 3 then raise exception 'Challenge is not complete yet.'; end if;
      wi := 10000;
    elsif p_action->>'key'='play4' then
      if s1 < 4 then raise exception 'Challenge is not complete yet.'; end if;
      wi := 5000;
    else
      select coalesce(sum(case
        when x->>'p1'=p_name then (x->>'s1')::int-(x->>'s2')::int
        else (x->>'s2')::int-(x->>'s1')::int end),0)::int into s1
      from jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) x
      where x->>'s1' is not null and (x->>'p1'=p_name or x->>'p2'=p_name);
      if s1 < 10 then raise exception 'Challenge is not complete yet.'; end if;
      wi := 7500;
    end if;

    d := jsonb_set(d,'{challengeClaims}',coalesce(d->'challengeClaims','[]'::jsonb),true);
    d := jsonb_set(d,'{chips}',coalesce(d->'chips','{}'::jsonb),true);
    d := jsonb_set(d,array['chips',p_name],to_jsonb(coalesce((d->'chips'->>p_name)::int,1000)+wi),true);
    d := jsonb_set(d,'{challengeClaims}',(d->'challengeClaims') || jsonb_build_array(jsonb_build_object(
      'week',(w->>'n')::int,'player',p_name,'key',p_action->>'key','reward',wi,'at',(extract(epoch from now())*1000)::bigint
    )));

  elsif t = 'prestige' then
    d := jsonb_set(d,'{progression}',coalesce(d->'progression','{}'::jsonb),true);
    g := coalesce(d->'progression'->p_name,'{}'::jsonb);
    wi := public.book_player_xp(d,p_name);
    if wi - coalesce((g->>'xpOffset')::int,0) < 12000 then raise exception 'Reach level 25 first.'; end if;
    d := jsonb_set(d,array['progression',p_name],jsonb_build_object(
      'prestige',coalesce((g->>'prestige')::int,0)+1,
      'xpOffset',wi,
      'at',(extract(epoch from now())*1000)::bigint
    ),true);

  elsif t = 'fantasyPick' then
    w := d->'weeks'->(jsonb_array_length(d->'weeks')-1);
    if coalesce((w->>'closed')::boolean,false) then raise exception 'Fantasy picks are locked for this game week.'; end if;
    if exists (select 1 from jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) x where x->>'s1' is not null) then
      raise exception 'Fantasy picks are locked for this game week.';
    end if;
    if jsonb_typeof(p_action->'picks') <> 'array' or jsonb_array_length(p_action->'picks') <> 4 then raise exception 'Pick four different players.'; end if;
    select count(distinct value)::int into s1 from jsonb_array_elements_text(p_action->'picks');
    if s1 <> 4 then raise exception 'Pick four different players.'; end if;

    d := jsonb_set(d,'{fantasyWeeks}',coalesce(d->'fantasyWeeks','{}'::jsonb),true);
    bid := w->>'n';
    g := d->'fantasyWeeks'->bid;
    if g is null then
      g := jsonb_build_object('tiers',public.book_fantasy_tiers(d),'picks','{}'::jsonb,'paid',false);
    end if;
    if not ((g->'tiers'->'elite') ? (p_action->'picks'->>0))
       or not ((g->'tiers'->'challenger') ? (p_action->'picks'->>1))
       or not ((g->'tiers'->'mongs') ? (p_action->'picks'->>2))
       or not ((g->'tiers'->'mongs') ? (p_action->'picks'->>3)) then
      raise exception 'Team must be 1 Elite, 1 Challenger and 2 Mongs.';
    end if;
    g := jsonb_set(g,array['picks',p_name],p_action->'picks',true);
    d := jsonb_set(d,array['fantasyWeeks',bid],g,true);

  elsif t = 'bountyPost' then
    w := d->'weeks'->(jsonb_array_length(d->'weeks')-1);
    g := null;
    select value into g
    from jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb))
    where value->>'id'=p_action->>'game'
    limit 1;
    if g is null then raise exception 'Pick a current game-week league fixture.'; end if;
    if g->>'s1' is not null or g->>'status' <> 'open' then raise exception 'That match has already started reporting or finished.'; end if;
    if p_action->>'hunter' <> g->>'p1' and p_action->>'hunter' <> g->>'p2' then raise exception 'Pick one of the two players.'; end if;
    wi := floor((p_action->>'amount')::numeric)::int;
    if wi is null or wi < 1000 or wi > 100000 then raise exception 'Bounties are 1,000 to 100,000 chips.'; end if;
    if wi > coalesce((d->'chips'->>p_name)::int,1000) then raise exception 'Not enough chips.'; end if;

    d := jsonb_set(d,'{bounties}',coalesce(d->'bounties','[]'::jsonb),true);
    d := jsonb_set(d,'{chips}',coalesce(d->'chips','{}'::jsonb),true);
    d := jsonb_set(d,array['chips',p_name],to_jsonb(coalesce((d->'chips'->>p_name)::int,1000)-wi),true);
    bid := 'bo' || ((extract(epoch from clock_timestamp())*1000)::bigint)::text;
    d := jsonb_set(d,'{bounties}',(d->'bounties') || jsonb_build_array(jsonb_build_object(
      'id',bid,'sponsor',p_name,'game',g->>'id','hunter',p_action->>'hunter',
      'target',case when p_action->>'hunter'=g->>'p1' then g->>'p2' else g->>'p1' end,
      'amount',wi,'status','open','at',(extract(epoch from now())*1000)::bigint
    )));

  elsif t = 'bountyCancel' then
    i := null;
    if jsonb_array_length(coalesce(d->'bounties','[]'::jsonb)) > 0 then
      for j in 0..jsonb_array_length(d->'bounties')-1 loop
        if d->'bounties'->j->>'id'=p_action->>'id' then i:=j; exit; end if;
      end loop;
    end if;
    if i is null then raise exception 'That bounty is gone.'; end if;
    g := d->'bounties'->i;
    if g->>'status' <> 'open' then raise exception 'That bounty is no longer open.'; end if;
    if g->>'sponsor' <> p_name then raise exception 'Only the sponsor can cancel it.'; end if;

    w := d->'weeks'->(jsonb_array_length(d->'weeks')-1);
    if exists (
      select 1 from jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) x
      where x->>'id'=g->>'game' and x->>'status' <> 'open'
    ) then raise exception 'Too late to cancel; score reporting has started.'; end if;

    wi := coalesce((g->>'amount')::int,0);
    d := jsonb_set(d,array['chips',p_name],to_jsonb(coalesce((d->'chips'->>p_name)::int,1000)+wi),true);
    g := g || jsonb_build_object('status','cancelled','cancelledAt',(extract(epoch from now())*1000)::bigint);
    d := jsonb_set(d,array['bounties',i::text],g,true);
$actions$;
begin
  select pg_get_functiondef('public.book_player_action(text,text,jsonb)'::regprocedure) into f;

  if position('elsif t = ''placeScoreBet'' then' in f) = 0 then
    if position('  elsif t = ''c4Create'' then' in f) = 0 then
      raise exception 'Book1 1.8.7 migration stopped: c4Create anchor not found.';
    end if;
    f := replace(f,'  elsif t = ''c4Create'' then',actions || E'\n  elsif t = ''c4Create'' then');
  end if;

  if position('public.book_bs_separated_ships' in f) = 0 then
    if position('if not bs_valid_ships(p_action->''ships'') then' in f) = 0 then
      raise exception 'Book1 1.8.7 migration stopped: Battleships validation anchor not found.';
    end if;
    f := replace(
      f,
      'if not bs_valid_ships(p_action->''ships'') then',
      'if not bs_valid_ships(p_action->''ships'') or not public.book_bs_separated_ships(p_action->''ships'') then'
    );
  end if;

  if position('d := public.book_settle_187(d);' in f) = 0 then
    f := regexp_replace(
      f,
      E'\n([[:space:]]*)update public\\.book',
      E'\n\\1d := public.book_settle_187(d);\n\n\\1update public.book',
      'i'
    );
    if position('d := public.book_settle_187(d);' in f) = 0 then
      raise exception 'Book1 1.8.7 migration stopped: final book update anchor not found.';
    end if;
  end if;

  execute f;
end
$$;

create or replace function public.book_version()
returns integer
language sql
as $function$
  select 29
$function$;

commit;

-- Verification: expect 29 / true / true / true / true.
select
  public.book_version() as database_function_version,
  position(
    'elsif t = ''placeScoreBet'' then' in
    pg_get_functiondef('public.book_player_action(text,text,jsonb)'::regprocedure)
  ) > 0 as feature_actions_installed,
  position(
    'd := public.book_settle_187(d);' in
    pg_get_functiondef('public.book_player_action(text,text,jsonb)'::regprocedure)
  ) > 0 as settlement_hook_installed,
  position(
    'book_bs_separated_ships' in
    pg_get_functiondef('public.book_player_action(text,text,jsonb)'::regprocedure)
  ) > 0 as battleships_separation_installed,
  (select data ? 'fantasyWeeks' and data ? 'bounties' and data ? 'scoreBets' from public.book where id=1) as new_collections_ready;
