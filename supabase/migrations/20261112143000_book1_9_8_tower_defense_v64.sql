-- Book1 1.9.8 Tower Defense server-validated sessions and rewards.
CREATE OR REPLACE FUNCTION public.book_tower_defense_start(p_name text,p_pin text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','extensions' AS $$
DECLARE d jsonb; v int; bal int; wn int; tok text; now_ms bigint;
BEGIN
 IF public.book_check(p_name,p_pin) IS NULL THEN RAISE EXCEPTION 'Wrong name or PIN'; END IF;
 SELECT data,version INTO d,v FROM public.book WHERE id=1 FOR UPDATE;
 now_ms:=(extract(epoch from clock_timestamp())*1000)::bigint;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(d->'towerDefenseSessions','[]'::jsonb)) x WHERE x->>'player'=p_name AND x->>'status'='playing' AND now_ms-coalesce((x->>'startedAt')::bigint,0)<3600000) THEN RAISE EXCEPTION 'You already have a Tower Defense game in progress.'; END IF;
 bal:=coalesce((d->'chips'->>p_name)::int,1000); IF bal<100 THEN RAISE EXCEPTION 'You need 100 chips to play Tower Defense.'; END IF;
 wn:=(d->'weeks'->(jsonb_array_length(d->'weeks')-1)->>'n')::int; tok:=md5(random()::text||clock_timestamp()::text||p_name);
 d:=jsonb_set(d,'{chips}',coalesce(d->'chips','{}'::jsonb),true); d:=jsonb_set(d,array['chips',p_name],to_jsonb(bal-100),true);
 d:=jsonb_set(d,'{towerDefenseSessions}',coalesce(d->'towerDefenseSessions','[]'::jsonb)||jsonb_build_array(jsonb_build_object('token',tok,'player',p_name,'status','playing','week',wn,'startedAt',now_ms)),true);
 UPDATE public.book SET data=d,version=v+1,updated_at=now() WHERE id=1; RETURN jsonb_build_object('token',tok,'balance',bal-100,'version',v+1);
END $$;
CREATE OR REPLACE FUNCTION public.book_tower_defense_finish(p_name text,p_pin text,p_token text,p_stats jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','extensions' AS $$
DECLARE d jsonb; v int; sess jsonb; idx int; now_ms bigint; elapsed int; sc int; kw int; wv int; lv int; xp int; rec jsonb;
BEGIN
 IF public.book_check(p_name,p_pin) IS NULL THEN RAISE EXCEPTION 'Wrong name or PIN'; END IF;
 IF jsonb_typeof(p_stats)<>'object' THEN RAISE EXCEPTION 'Invalid Tower Defense result.'; END IF;
 SELECT data,version INTO d,v FROM public.book WHERE id=1 FOR UPDATE; now_ms:=(extract(epoch from clock_timestamp())*1000)::bigint;
 SELECT ordinality::int-1,value INTO idx,sess FROM jsonb_array_elements(coalesce(d->'towerDefenseSessions','[]'::jsonb)) WITH ORDINALITY z(value,ordinality) WHERE value->>'token'=p_token AND value->>'player'=p_name AND value->>'status'='playing' LIMIT 1;
 IF idx IS NULL THEN RAISE EXCEPTION 'That Tower Defense game is already finished or invalid.'; END IF;
 elapsed:=((now_ms-(sess->>'startedAt')::bigint)/1000)::int; IF elapsed<20 THEN RAISE EXCEPTION 'Play for at least 20 seconds before submitting a score.'; END IF; IF elapsed>3600 THEN RAISE EXCEPTION 'That Tower Defense session has expired.'; END IF;
 sc:=greatest(0,least(2000000,coalesce((p_stats->>'score')::int,0))); kw:=greatest(0,least(1000,coalesce((p_stats->>'kills')::int,0))); wv:=greatest(0,least(50,coalesce((p_stats->>'wave')::int,0))); lv:=greatest(0,least(20,coalesce((p_stats->>'lives')::int,0)));
 IF wv>floor(elapsed/8.0)+1 OR kw>wv*30 OR sc>kw*120+wv*600+lv*2 THEN RAISE EXCEPTION 'Tower Defense score failed server validation.'; END IF;
 xp:=floor(sc/200.0)::int; rec:=jsonb_build_object('player',p_name,'score',sc,'kills',kw,'wave',wv,'lives',lv,'xp',xp,'week',(sess->>'week')::int,'at',now_ms,'serverValidated',true);
 d:=jsonb_set(d,array['towerDefenseSessions',idx::text],sess||jsonb_build_object('status','finished','finishedAt',now_ms,'score',sc,'wave',wv),true);
 d:=jsonb_set(d,'{towerDefenseScores}',coalesce(d->'towerDefenseScores','[]'::jsonb)||jsonb_build_array(rec),true);
 d:=jsonb_set(d,'{log}',coalesce(d->'log','[]'::jsonb)||to_jsonb(format('%s completed Tower Defense: %s points, wave %s',p_name,sc,wv)),true);
 UPDATE public.book SET data=d,version=v+1,updated_at=now() WHERE id=1; RETURN jsonb_build_object('score',sc,'kills',kw,'wave',wv,'lives',lv,'xp',xp,'serverValidated',true,'version',v+1);
END $$;
DO $$
DECLARE f text;
BEGIN
 SELECT pg_get_functiondef('public.book_weekly_challenge_189(jsonb,text,text)'::regprocedure) INTO f;
 f:=replace(f,
 ' elsif p_key in (''spins2'',''spins5'') then',
 ' elsif p_key in (''tdgames3'',''tdwave15'') then
  if p_key=''tdgames3'' then
   select count(*)::int into v from jsonb_array_elements(coalesce(d->''towerDefenseScores'',''[]''::jsonb)) x where x->>''player''=p_player and coalesce((x->>''week'')::int,-1)=wn and coalesce((x->>''at'')::bigint,0)>=challenge_start;
   target:=3; reward:=10000; xp_reward:=1400;
  else
   select coalesce(max((x->>''wave'')::int),0)::int into v from jsonb_array_elements(coalesce(d->''towerDefenseScores'',''[]''::jsonb)) x where x->>''player''=p_player and coalesce((x->>''week'')::int,-1)=wn and coalesce((x->>''at'')::bigint,0)>=challenge_start;
   target:=15; reward:=15000; xp_reward:=2200;
  end if;
 elsif p_key in (''spins2'',''spins5'') then');
 EXECUTE f;
END $$;
