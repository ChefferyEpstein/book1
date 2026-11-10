-- Book1 v53: batch settlement lookups and prediction reward JSON updates.
CREATE OR REPLACE FUNCTION public.book_settle_json(d0 jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
declare d jsonb := d0; i int; j int; n int; b jsonb; g jsonb; pl text; stake int; pay int; cur int;
        lgs jsonb; lg jsonb; ls text; lost boolean; open_left boolean; anywon boolean; prod float8; eff float8;
        games_by_id jsonb; chip_updates jsonb; marker_updates jsonb; reward_logs jsonb;
begin
  if d->'bets' is null or jsonb_typeof(d->'bets') <> 'array' then
    d := jsonb_set(d, '{bets}', '[]'::jsonb, true);
  end if;
  d := d || jsonb_build_object(
    'chips', coalesce(d->'chips','{}'::jsonb),
    'log', coalesce(d->'log','[]'::jsonb),
    'predictionRewards', coalesce(d->'predictionRewards','{}'::jsonb)
  );
  -- Build one fixture index instead of recursively searching the full Book JSON for every bet leg.
  select coalesce(jsonb_object_agg(game_id, fixture), '{}'::jsonb)
    into games_by_id
  from (
    select distinct on (fixture->>'id')
           fixture->>'id' as game_id, fixture
    from jsonb_array_elements(coalesce(d->'weeks','[]'::jsonb)) with ordinality as w(wk, week_ord)
    cross join lateral jsonb_array_elements(coalesce(w.wk->'fixtures','[]'::jsonb)) with ordinality as f(fixture, fixture_ord)
    where fixture->>'id' is not null
    order by fixture->>'id', week_ord, fixture_ord
  ) indexed_games;
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
          g := games_by_id->(lg->>'game');
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
    g := games_by_id->(b->>'game');
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
  -- Batch all newly-earned prediction rewards. Existing true/false markers remain untouched,
  -- so retries are idempotent and historical predictions are never paid retroactively.
  with completed as (
    select fixture->>'id' as fixture_id,
           case when (fixture->>'s1')::int > (fixture->>'s2')::int
                then fixture->>'p1' else fixture->>'p2' end as winner
    from jsonb_array_elements(coalesce(d->'weeks','[]'::jsonb)) as w(wk)
    cross join lateral jsonb_array_elements(coalesce(w.wk->'fixtures','[]'::jsonb)) as f(fixture)
    where fixture->>'s1' is not null
      and fixture->>'s2' is not null
      and fixture->>'id' is not null
  ), eligible as (
    select distinct c.fixture_id, p.key as player, p.value as pick
    from completed c
    cross join lateral jsonb_each_text(
      case when jsonb_typeof(d->'predictions'->c.fixture_id) = 'object'
           then d->'predictions'->c.fixture_id else '{}'::jsonb end
    ) as p(key, value)
    where p.value = c.winner
      and d #> array['predictionRewards', c.fixture_id, p.key] is null
  ), player_totals as (
    select player, count(*)::int as reward_count
    from eligible
    group by player
  ), fixture_players as (
    select fixture_id, jsonb_object_agg(player, 'true'::jsonb) as players
    from eligible
    group by fixture_id
  )
  select
    coalesce((
      select jsonb_object_agg(
        player,
        to_jsonb(coalesce((d->'chips'->>player)::int, 1000) + reward_count * 500)
      ) from player_totals
    ), '{}'::jsonb),
    coalesce((
      select jsonb_object_agg(
        fixture_id,
        (case when jsonb_typeof(d->'predictionRewards'->fixture_id) = 'object'
              then d->'predictionRewards'->fixture_id else '{}'::jsonb end) || players
      ) from fixture_players
    ), '{}'::jsonb),
    coalesce((
      select jsonb_agg(
        to_jsonb(format('%s correctly predicted %s to win (+500 chips and 100 XP)', player, pick))
        order by fixture_id, player
      ) from eligible
    ), '[]'::jsonb)
  into chip_updates, marker_updates, reward_logs;

  d := d || jsonb_build_object(
    'chips', (d->'chips') || chip_updates,
    'predictionRewards', (d->'predictionRewards') || marker_updates,
    'log', (d->'log') || reward_logs
  );
  return d;
exception when others then
  return d0;
end $function$
;

create or replace function public.book_version()
returns integer
language sql
set search_path to 'public', 'extensions'
as $function$
  select 53
$function$;
