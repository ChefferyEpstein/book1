-- Book1 1.9.8: support the expanded rotating weekly Pinball challenges (SQL v80).
-- The client has included Arcade Fixture (pinplays7) and other higher-tier Pinball
-- challenges in its 50-task rotation; the server validator must recognise the same IDs.

DO $$
DECLARE
  fn text;
  old_ids text := $old$elsif p_key in ('pinplays3','pinplays5','pinscore50000','pinscore125000','pinscore200000','pinscore250000') then$old$;
  new_ids text := $new$elsif p_key in ('pinplays3','pinplays5','pinplays7','pinplays10','pinscore50000','pinscore125000','pinscore200000','pinscore250000','pinscore300000','pinscore400000') then$new$;
  old_targets text := $old$target:=case p_key when 'pinscore50000' then 1000 when 'pinscore125000' then 5000 when 'pinscore200000' then 10000 else 20000 end;
  else target:=case p_key when 'pinplays3' then 3 else 5 end; end if;$old$;
  new_targets text := $new$target:=case p_key
     when 'pinscore50000' then 15000
     when 'pinscore125000' then 40000
     when 'pinscore200000' then 60000
     when 'pinscore250000' then 90000
     when 'pinscore300000' then 300000
     else 400000 end;
  else target:=case p_key when 'pinplays3' then 3 when 'pinplays5' then 5 when 'pinplays7' then 7 else 10 end; end if;$new$;
  old_rewards text := $old$reward:=case p_key when 'pinplays3' then 10000 when 'pinplays5' then 20000 when 'pinscore50000' then 10000 when 'pinscore125000' then 17500 when 'pinscore200000' then 25000 else 40000 end;
  xp_reward:=case p_key when 'pinplays3' then 1400 when 'pinplays5' then 2600 when 'pinscore50000' then 1500 when 'pinscore125000' then 2500 when 'pinscore200000' then 3500 else 5000 end;$old$;
  new_rewards text := $new$reward:=case p_key
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
    when 'pinscore300000' then 4500 else 6500 end;$new$;
BEGIN
  fn := pg_get_functiondef('public.book_weekly_challenge_189(jsonb,text,text)'::regprocedure);
  IF position(old_ids in fn)=0 OR position(old_targets in fn)=0 OR position(old_rewards in fn)=0 THEN
    RAISE EXCEPTION 'Expected weekly Pinball validation block was not found; migration stopped.';
  END IF;
  fn := replace(fn,old_ids,new_ids);
  fn := replace(fn,old_targets,new_targets);
  fn := replace(fn,old_rewards,new_rewards);
  EXECUTE fn;
END
$$;

CREATE OR REPLACE FUNCTION public.book_version()
RETURNS integer LANGUAGE sql STABLE SET search_path TO 'public','extensions'
AS $function$ SELECT 80; $function$;
