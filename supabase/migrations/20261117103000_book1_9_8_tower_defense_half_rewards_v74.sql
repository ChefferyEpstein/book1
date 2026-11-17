-- Book1 1.9.8 SQL v74: halve Tower Defense rewards.
-- Previous rates: 5% XP and 10% chips. New rates: 2.5% XP and 5% chips.
CREATE OR REPLACE FUNCTION public.book_tower_defense_finish(p_name text, p_pin text, p_token text, p_stats jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE d jsonb; v int; sess jsonb; idx int; now_ms bigint; elapsed int; sc int; kw int; wv int; lv int; xp int; chips_reward int; rec jsonb;
BEGIN
 IF public.book_check(p_name,p_pin) IS NULL THEN RAISE EXCEPTION 'Wrong name or PIN'; END IF;
 IF jsonb_typeof(p_stats)<>'object' THEN RAISE EXCEPTION 'Invalid Tower Defense result.'; END IF;
 SELECT data,version INTO d,v FROM public.book WHERE id=1 FOR UPDATE;
 now_ms:=(extract(epoch from clock_timestamp())*1000)::bigint;
 SELECT ordinality::int-1,value INTO idx,sess FROM jsonb_array_elements(coalesce(d->'towerDefenseSessions','[]'::jsonb)) WITH ORDINALITY z(value,ordinality) WHERE value->>'token'=p_token AND value->>'player'=p_name AND value->>'status'='playing' LIMIT 1;
 IF idx IS NULL THEN RAISE EXCEPTION 'That Tower Defense game is already finished or invalid.'; END IF;
 elapsed:=((now_ms-(sess->>'startedAt')::bigint)/1000)::int; IF elapsed<20 THEN RAISE EXCEPTION 'Play for at least 20 seconds before submitting a score.'; END IF; IF elapsed>3600 THEN RAISE EXCEPTION 'That Tower Defense session has expired.'; END IF;
 sc:=greatest(0,coalesce((p_stats->>'score')::int,0)); kw:=greatest(0,coalesce((p_stats->>'kills')::int,0)); wv:=greatest(0,least(50,coalesce((p_stats->>'wave')::int,0))); lv:=greatest(0,least(20,coalesce((p_stats->>'lives')::int,0)));
 IF wv>floor(elapsed/8.0)+1
    OR kw>coalesce((SELECT sum(ceil((8::double precision+g*2+0.025::double precision*g*g)*1.25::double precision)::int) FROM generate_series(1,wv) AS waves(g)),0)
    OR sc>80260
    OR sc::bigint>kw::bigint*56
  THEN RAISE EXCEPTION 'Tower Defense score failed server validation.'; END IF;
 xp:=floor(sc/40.0)::int; chips_reward:=floor(sc/20.0)::int; rec:=jsonb_build_object('player',p_name,'score',sc,'kills',kw,'wave',wv,'lives',lv,'xp',xp,'chipsReward',chips_reward,'week',(sess->>'week')::int,'at',now_ms,'serverValidated',true);
 d:=jsonb_set(d,'{chips}',coalesce(d->'chips','{}'::jsonb),true); d:=jsonb_set(d,array['chips',p_name],to_jsonb(coalesce((d->'chips'->>p_name)::int,0)+chips_reward),true); d:=jsonb_set(d,array['towerDefenseSessions',idx::text],sess||jsonb_build_object('status','finished','finishedAt',now_ms,'score',sc,'wave',wv),true);
 d:=jsonb_set(d,'{towerDefenseScores}',coalesce(d->'towerDefenseScores','[]'::jsonb)||jsonb_build_array(rec),true);
 d:=jsonb_set(d,'{log}',coalesce(d->'log','[]'::jsonb)||to_jsonb(format('%s completed Tower Defense: %s points, wave %s',p_name,sc,wv)),true);
 UPDATE public.book SET data=d,version=v+1,updated_at=now() WHERE id=1; RETURN jsonb_build_object('score',sc,'kills',kw,'wave',wv,'lives',lv,'xp',xp,'chips',chips_reward,'serverValidated',true,'version',v+1);
END $function$;

CREATE OR REPLACE FUNCTION public.book_version()
RETURNS integer LANGUAGE sql SET search_path TO 'public','extensions'
AS $function$ SELECT 74 $function$;
