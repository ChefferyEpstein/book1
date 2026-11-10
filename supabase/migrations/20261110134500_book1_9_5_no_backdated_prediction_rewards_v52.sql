-- Book1 v52: distinguish historical processed predictions from rewarded predictions.
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
           and d #> array['predictionRewards',fixture_id,pred_player] is null then
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

create or replace function public.book_version()
returns integer
language sql
set search_path to 'public', 'extensions'
as $function$
  select 52
$function$;
