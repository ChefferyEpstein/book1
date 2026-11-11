drop function if exists public.book_pinball_finish(text,text,text,integer);

create or replace function public.book_pinball_finish(
  p_name text,
  p_pin text,
  p_token text,
  p_events jsonb
) returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
declare
  d jsonb;
  v int;
  i int;
  sess jsonb;
  elapsed bigint;
  prize int;
  balance int;
  rec jsonb;
  now_ms bigint;
  ev jsonb;
  ev_type text;
  ev_index int;
  ev_t bigint;
  prev_t bigint := -1;
  prev_key_t bigint;
  event_key text;
  last_by_key jsonb := '{}'::jsonb;
  base_points int;
  bounce_count int := 0;
  calculated_score bigint := 0;
  event_count int := 0;
  cooldown_ms int;
begin
  if public.book_check(p_name,p_pin) is null then
    raise exception 'Wrong name or PIN';
  end if;
  if p_events is null or jsonb_typeof(p_events) <> 'array' then
    raise exception 'Invalid Pinball scoring record.';
  end if;
  if jsonb_array_length(p_events) > 3000 then
    raise exception 'Pinball scoring record is too large.';
  end if;

  select data,version into d,v from public.book where id=1 for update;
  now_ms := (extract(epoch from clock_timestamp())*1000)::bigint;

  for rec in
    select value from jsonb_array_elements(coalesce(d->'pinballSessions','[]'::jsonb))
  loop
    if rec->>'token'=p_token and rec->>'player'=p_name and rec->>'status'='playing' then
      i := (select ord::int-1
            from jsonb_array_elements(coalesce(d->'pinballSessions','[]'::jsonb)) with ordinality as z(value,ord)
            where value=rec limit 1);
      sess := rec;
      exit;
    end if;
  end loop;

  if i is null or sess is null then
    raise exception 'That Pinball game has already finished or is invalid.';
  end if;

  elapsed := now_ms-(sess->>'startedAt')::bigint;

  if elapsed > 105000 then
    d := jsonb_set(d,array['pinballSessions',i::text],
      sess||jsonb_build_object('status','expired','expiredAt',now_ms,'expireReason','time limit reached'),true);
    update public.book set data=d,version=v+1,updated_at=now() where id=1;
    return jsonb_build_object('expired',true,'version',v+1);
  end if;

  if elapsed<15000 then
    raise exception 'Play for at least 15 seconds before submitting a score.';
  end if;

  -- Recalculate every scoring award on the server. The browser no longer supplies a score.
  for ev in select value from jsonb_array_elements(p_events) loop
    if jsonb_typeof(ev) <> 'object' then
      raise exception 'Invalid Pinball scoring event.';
    end if;

    ev_type := ev->>'type';
    ev_index := nullif(ev->>'index','')::int;
    ev_t := nullif(ev->>'t','')::bigint;

    if ev_index is null or ev_t is null or ev_t < 0 or ev_t > least(elapsed,90000) then
      raise exception 'Invalid Pinball event timing.';
    end if;
    if ev_t < prev_t then
      raise exception 'Pinball events are out of order.';
    end if;
    prev_t := ev_t;

    if ev_type='bumper' and ev_index between 0 and 4 then
      base_points := case ev_index when 0 then 250 when 1 then 250 when 2 then 100 when 3 then 150 else 150 end;
      cooldown_ms := 120;
    elsif ev_type='target' and ev_index between 0 and 1 then
      base_points := 250;
      cooldown_ms := 300;
    elsif ev_type='sling' and ev_index=0 then
      base_points := 25;
      cooldown_ms := 250;
    elsif ev_type='flipper' and ev_index=0 then
      base_points := 10;
      cooldown_ms := 180;
    else
      raise exception 'Unknown Pinball scoring event.';
    end if;

    event_key := ev_type||':'||ev_index::text;
    prev_key_t := nullif(last_by_key->>event_key,'')::bigint;
    if prev_key_t is not null and ev_t-prev_key_t < cooldown_ms then
      raise exception 'Pinball scoring events are too frequent.';
    end if;

    last_by_key := jsonb_set(last_by_key,array[event_key],to_jsonb(ev_t),true);
    bounce_count := bounce_count+1;
    calculated_score := calculated_score + round(base_points::numeric*(1+bounce_count*.01));
    event_count := event_count+1;
  end loop;

  if calculated_score > 2147483647 then
    raise exception 'Pinball score is outside the supported range.';
  end if;

  prize := floor(calculated_score * 0.05)::int;
  balance := coalesce((d->'chips'->>p_name)::int,1000);
  d := jsonb_set(d,array['pinballSessions',i::text],
    sess||jsonb_build_object('status','finished','score',calculated_score,'prize',prize,
      'finishedAt',now_ms,'serverValidated',true,'scoreEventCount',event_count),true);
  d := jsonb_set(d,'{chips}',coalesce(d->'chips','{}'::jsonb),true);
  d := jsonb_set(d,array['chips',p_name],to_jsonb(balance+prize),true);
  d := jsonb_set(d,'{pinballScores}',coalesce(d->'pinballScores','[]'::jsonb)||jsonb_build_array(jsonb_build_object(
    'player',p_name,'score',calculated_score,'prize',prize,'week',(sess->>'week')::int,'at',now_ms,
    'serverValidated',true,'eventCount',event_count
  )),true);
  d := jsonb_set(d,'{log}',coalesce(d->'log','[]'::jsonb)||to_jsonb(format('%s scored %s on Pinball and won %s chips',p_name,calculated_score,prize)),true);

  update public.book set data=d,version=v+1,updated_at=now() where id=1;
  return jsonb_build_object('score',calculated_score,'prize',prize,'balance',balance+prize,
    'eventCount',event_count,'serverValidated',true,'version',v+1);
end
$function$;

create or replace function public.book_version()
returns integer
language sql
set search_path to 'public','extensions'
as $function$
  select 55
$function$;