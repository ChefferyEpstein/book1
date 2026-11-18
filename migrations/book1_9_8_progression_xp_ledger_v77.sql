-- Book1 1.9.8: durable server-side XP balance (SQL v77)
-- Reuses the existing canonical XP calculation, aligns Tower Defense to the live 0.5% rule,
-- and snapshots each player's raw-history checkpoint so trimmed records cannot erase earned XP.

CREATE OR REPLACE FUNCTION public.book_player_xp(p_data jsonb, p_player text)
RETURNS integer
LANGUAGE plpgsql
STABLE
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  w jsonb;
  g jsonb;
  xp integer := 0;
  gd integer;
  bd integer;
  pinball_reset_at bigint := coalesce((p_data->>'pinballXPResetAt')::bigint,0);
  pinball_half_rate_from bigint := 1794404120183;
BEGIN
  FOR w IN SELECT value FROM jsonb_array_elements(coalesce(p_data->'weeks','[]'::jsonb)) LOOP
    FOR g IN SELECT value FROM jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) LOOP
      IF g->>'s1' IS NULL OR (g->>'p1'<>p_player AND g->>'p2'<>p_player) THEN CONTINUE; END IF;
      xp := xp + 100;
      IF (((g->>'s1')::int>(g->>'s2')::int AND g->>'p1'=p_player) OR ((g->>'s2')::int>(g->>'s1')::int AND g->>'p2'=p_player)) THEN xp := xp + 200; END IF;
      gd := CASE WHEN g->>'p1'=p_player THEN (g->>'s1')::int-(g->>'s2')::int ELSE (g->>'s2')::int-(g->>'s1')::int END;
      IF gd > 0 THEN xp := xp + gd*10; END IF;
    END LOOP;
  END LOOP;
  FOR g IN SELECT value FROM jsonb_array_elements(coalesce(p_data->'connect4','[]'::jsonb)) LOOP
    IF g->>'status' IN ('done','draw') AND (g->>'challenger'=p_player OR g->>'opponent'=p_player) THEN
      xp := xp+50; IF g->>'winner'=p_player THEN xp:=xp+100; END IF;
    END IF;
  END LOOP;
  FOR g IN SELECT value FROM jsonb_array_elements(coalesce(p_data->'battleships','[]'::jsonb)) LOOP
    IF g->>'status'='done' AND (g->>'challenger'=p_player OR g->>'opponent'=p_player) THEN
      xp:=xp+50; IF g->>'winner'=p_player THEN xp:=xp+100; END IF;
    END IF;
  END LOOP;
  FOR g IN SELECT value FROM jsonb_array_elements(coalesce(p_data->'hogDuels','[]'::jsonb)) LOOP
    IF g->>'status'='done' AND (g->>'challenger'=p_player OR g->>'opponent'=p_player) THEN
      xp:=xp+25; IF g->>'winner'=p_player THEN xp:=xp+50; END IF;
    END IF;
  END LOOP;
  FOR g IN SELECT value FROM jsonb_array_elements(coalesce(p_data->'chess','[]'::jsonb)) LOOP
    IF g->>'status' IN ('done','draw') AND (g->>'challenger'=p_player OR g->>'opponent'=p_player) THEN
      xp:=xp+75;
      IF g->>'winner'=p_player THEN xp:=xp+150; ELSIF g->>'status'='draw' THEN xp:=xp+50; END IF;
    END IF;
  END LOOP;
  SELECT coalesce(sum(coalesce((x->>'xp')::int,0)),0)::int INTO gd
  FROM jsonb_array_elements(coalesce(p_data->'challengeClaims','[]'::jsonb)) x WHERE x->>'player'=p_player;
  SELECT coalesce(sum(coalesce((x->>'xp')::int,0)),0)::int INTO bd
  FROM jsonb_array_elements(coalesce(p_data->'brainClaims','[]'::jsonb)) x WHERE x->>'player'=p_player;
  xp := xp + (SELECT count(*)::int*100 FROM jsonb_each(coalesce(p_data->'predictionRewards','{}'::jsonb)) r WHERE r.value->>p_player='true');
  RETURN xp+gd+bd
    + coalesce((p_data->'caseXP'->>p_player)::integer,0)
    + public.book_fantasy_week_xp(p_data,p_player)
    + floor(greatest(0,coalesce((p_data->'pinballArchivedXP'->>p_player)::numeric,0)))::int
    + (SELECT coalesce(sum(floor(greatest(0,coalesce((x->>'score')::numeric,0))/40)),0)::int
       FROM jsonb_array_elements(coalesce(p_data->'towerDefenseScores','[]'::jsonb)) x WHERE x->>'player'=p_player)
    + (SELECT coalesce(sum(floor(greatest(0,coalesce((x->>'score')::numeric,0)) /
          CASE WHEN coalesce((x->>'at')::bigint,0)>=pinball_half_rate_from THEN 200 ELSE 100 END)),0)::int
       FROM jsonb_array_elements(coalesce(p_data->'pinballScores','[]'::jsonb)) x
       WHERE x->>'player'=p_player AND coalesce((x->>'at')::bigint,0)>=pinball_reset_at);
END
$function$;

CREATE OR REPLACE FUNCTION public.book_sync_xp_balance()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  player_name text;
  old_progress jsonb;
  new_progress jsonb;
  old_prestige integer;
  new_prestige integer;
  raw_now integer;
  raw_before integer;
  raw_checkpoint integer;
  balance_now bigint;
  legacy_offset bigint;
  legacy_carry bigint;
BEGIN
  FOR player_name IN
    SELECT DISTINCT x->>'name'
    FROM jsonb_array_elements(coalesce(NEW.data->'players', OLD.data->'players', '[]'::jsonb)) x
    WHERE nullif(x->>'name','') IS NOT NULL
  LOOP
    old_progress := coalesce(OLD.data->'progression'->player_name,'{}'::jsonb);
    new_progress := coalesce(NEW.data->'progression'->player_name,'{}'::jsonb);
    old_prestige := coalesce((old_progress->>'prestige')::integer,0);
    new_prestige := coalesce((new_progress->>'prestige')::integer,old_prestige);
    IF new_prestige < old_prestige THEN
      new_prestige := old_prestige;
    END IF;

    raw_now := public.book_player_xp(NEW.data,player_name);
    raw_before := public.book_player_xp(OLD.data,player_name);

    IF new_prestige > old_prestige THEN
      -- Prestige starts a clean balance; history is checkpointed, never subtracted again.
      balance_now := 0;
      raw_checkpoint := raw_now;
    ELSE
      legacy_offset := coalesce((old_progress->>'xpOffset')::bigint,0);
      legacy_carry := coalesce((old_progress->>'xpCarry')::bigint,0);
      raw_checkpoint := coalesce((old_progress->>'xpRawCheckpoint')::integer,raw_before);
      balance_now := coalesce((old_progress->>'xpBalance')::bigint,
        greatest(0,raw_before-legacy_offset)::bigint + legacy_carry);
      -- Credit only positive changes. A later archive/history trim never removes balance.
      balance_now := balance_now + greatest(0,raw_now-raw_checkpoint);
      raw_checkpoint := raw_now;
    END IF;

    new_progress := new_progress
      || jsonb_build_object(
        'prestige',new_prestige,
        'xpBalance',greatest(0,balance_now),
        'xpRawCheckpoint',greatest(0,raw_checkpoint),
        'xpCarry',0
      );
    NEW.data := jsonb_set(coalesce(NEW.data,'{}'::jsonb),array['progression',player_name],new_progress,true);
  END LOOP;
  RETURN NEW;
END
$function$;

-- One-time reconciliation. The old xpCarry was a manual patch for historical claims;
-- it overlapped the claim history and is intentionally not carried into the new balance.
DO $$
DECLARE
  player_name text;
  raw_now integer;
  offset_now bigint;
  balance_now bigint;
  progression_now jsonb;
BEGIN
  FOR player_name IN
    SELECT x->>'name' FROM jsonb_array_elements(coalesce((SELECT data->'players' FROM public.book WHERE id=1),'[]'::jsonb)) x
    WHERE nullif(x->>'name','') IS NOT NULL
  LOOP
    SELECT data->'progression'->player_name INTO progression_now FROM public.book WHERE id=1;
    SELECT public.book_player_xp(data,player_name) INTO raw_now FROM public.book WHERE id=1;
    offset_now := coalesce((progression_now->>'xpOffset')::bigint,0);
    balance_now := greatest(0,raw_now-offset_now);
    -- The two common cases opened by Lorcan after the P5 reset were visible in the
    -- retained activity log, but caseXP itself had been lost: restore those 50 XP once.
    IF player_name='Lorcan'
       AND coalesce((progression_now->>'prestige')::integer,0)=5
       AND coalesce((SELECT data->'caseXP'->>'Lorcan' FROM public.book WHERE id=1),'')='' THEN
      balance_now := balance_now + 50;
    ELSE
      balance_now := balance_now + coalesce((progression_now->>'xpCarry')::bigint,0);
    END IF;
    UPDATE public.book
    SET data=jsonb_set(data,array['progression',player_name],
      coalesce(progression_now,'{}'::jsonb) || jsonb_build_object(
        'xpBalance',balance_now,
        'xpRawCheckpoint',raw_now,
        'xpCarry',0
      ),true)
    WHERE id=1;
  END LOOP;
END
$$;

DROP TRIGGER IF EXISTS book_sync_xp_balance_trigger ON public.book;
CREATE TRIGGER book_sync_xp_balance_trigger
BEFORE UPDATE OF data ON public.book
FOR EACH ROW EXECUTE FUNCTION public.book_sync_xp_balance();

CREATE OR REPLACE FUNCTION public.book_version()
RETURNS integer LANGUAGE sql STABLE
SET search_path TO 'public','extensions'
AS $function$ SELECT 77; $function$;
