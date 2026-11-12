-- Book1 1.9.8 SQL v68: award Tower Defense chip cashback at 1% of validated score.
DO $$
DECLARE f text;
BEGIN
 SELECT pg_get_functiondef('public.book_tower_defense_finish(text,text,text,jsonb)'::regprocedure) INTO f;
 IF position('chips_reward' in f)>0 THEN
  RAISE EXCEPTION 'Tower Defense chip reward already appears to be installed';
 END IF;
 f:=replace(f,
  'DECLARE d jsonb; v int; sess jsonb; idx int; now_ms bigint; elapsed int; sc int; kw int; wv int; lv int; xp int; rec jsonb;',
  'DECLARE d jsonb; v int; sess jsonb; idx int; now_ms bigint; elapsed int; sc int; kw int; wv int; lv int; xp int; chips_reward int; rec jsonb;');
 f:=replace(f,
  'xp:=floor(sc/200.0)::int; rec:=jsonb_build_object(''player'',p_name,''score'',sc,''kills'',kw,''wave'',wv,''lives'',lv,''xp'',xp,',
  'xp:=floor(sc/200.0)::int; chips_reward:=floor(sc/100.0)::int; rec:=jsonb_build_object(''player'',p_name,''score'',sc,''kills'',kw,''wave'',wv,''lives'',lv,''xp'',xp,''chipsReward'',chips_reward,');
 f:=replace(f,
  'd:=jsonb_set(d,array[''towerDefenseSessions'',idx::text],',
  'd:=jsonb_set(d,''{chips}'',coalesce(d->''chips'',''{}''::jsonb),true); d:=jsonb_set(d,array[''chips'',p_name],to_jsonb(coalesce((d->''chips''->>p_name)::int,0)+chips_reward),true); d:=jsonb_set(d,array[''towerDefenseSessions'',idx::text],');
 f:=replace(f,
  'RETURN jsonb_build_object(''score'',sc,''kills'',kw,''wave'',wv,''lives'',lv,''xp'',xp,''serverValidated'',true,',
  'RETURN jsonb_build_object(''score'',sc,''kills'',kw,''wave'',wv,''lives'',lv,''xp'',xp,''serverValidated'',true,');
 IF position('chips_reward' in f)=0 OR position('''chipsReward'',chips_reward' in f)=0 THEN
  RAISE EXCEPTION 'Could not safely patch Tower Defense reward function';
 END IF;
 EXECUTE f;
END $$;

CREATE OR REPLACE FUNCTION public.book_version()
RETURNS integer LANGUAGE sql SET search_path TO 'public','extensions'
AS $function$ SELECT 68 $function$;
