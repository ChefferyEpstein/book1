-- Book1 v51: record casino wheel spins in shared data for weekly challenge progress.
CREATE OR REPLACE FUNCTION public.book_spin_wheel(p_name text, p_pin text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  d jsonb;
  v int;
  last_spin bigint;
  now_ms bigint;
  roll numeric;
  amt int;
  wi int;
  stamp text;
  wait_mins int;
  segs jsonb;
  total_w numeric;
  cum numeric;
  seg jsonb;
  cooldown_mins int;
  cooldown_ms bigint;
begin
  if public.book_check(p_name,p_pin) is null then
    raise exception 'Wrong name or PIN';
  end if;

  select data, version into d, v
  from public.book
  where id = 1
  for update;

  now_ms := (extract(epoch from now())*1000)::bigint;
  stamp := to_char(now() at time zone 'Europe/London','DD Mon HH24:MI');
  cooldown_mins := public.book_wheel_cooldown_minutes(d,p_name);
  cooldown_ms := cooldown_mins * 60000::bigint;

  last_spin := nullif(d->'wheelSpins'->>p_name,'')::bigint;
  if last_spin is not null and now_ms - last_spin < cooldown_ms then
    wait_mins := ceil((cooldown_ms - (now_ms - last_spin)) / 60000.0);
    raise exception 'Not ready yet, % minute% left.',
      wait_mins,
      case when wait_mins = 1 then '' else 's' end;
  end if;

  segs := d->'wheelSegments';
  if segs is null or jsonb_array_length(segs) = 0 then
    segs := '[{"amount":1500,"weight":1},{"amount":750,"weight":2},{"amount":400,"weight":4},{"amount":250,"weight":8},{"amount":150,"weight":12},{"amount":100,"weight":18},{"amount":75,"weight":25},{"amount":50,"weight":30}]'::jsonb;
  end if;

  select sum((x->>'weight')::numeric)
  into total_w
  from jsonb_array_elements(segs) x;

  if total_w is null or total_w <= 0 then
    total_w := 1;
  end if;

  roll := random() * total_w;
  cum := 0;
  amt := null;

  for seg in select * from jsonb_array_elements(segs)
  loop
    cum := cum + coalesce((seg->>'weight')::numeric, 0);
    if amt is null and roll < cum then
      amt := (seg->>'amount')::int;
    end if;
  end loop;

  if amt is null then
    amt := (segs->(jsonb_array_length(segs)-1)->>'amount')::int;
  end if;

  wi := coalesce((d->'chips'->>p_name)::int, 1000);
  d := jsonb_set(d, '{chips}', coalesce(d->'chips','{}'::jsonb), true);
  d := jsonb_set(d, array['chips',p_name], to_jsonb(wi + amt), true);
  d := jsonb_set(d, '{wheelSpins}', coalesce(d->'wheelSpins','{}'::jsonb), true);
  d := jsonb_set(d, array['wheelSpins',p_name], to_jsonb(now_ms), true);
  d := jsonb_set(d, '{wheelSpinHistory}', coalesce(d->'wheelSpinHistory','[]'::jsonb), true);
  d := jsonb_set(d, '{wheelSpinHistory}', (d->'wheelSpinHistory') || jsonb_build_array(jsonb_build_object('player',p_name,'at',now_ms,'amount',amt)), true);
  d := jsonb_set(d, '{wheelPending}', '{}'::jsonb, true);
  d := jsonb_set(
    d,
    '{log}',
    coalesce(d->'log','[]'::jsonb)
      || to_jsonb(stamp || ' ' || p_name || ' spun the wheel and won ' || amt || ' chips'),
    true
  );

  update public.book
  set data = d, version = v + 1, updated_at = now()
  where id = 1;

  return jsonb_build_object(
    'amount', amt,
    'next', now_ms + cooldown_ms,
    'cooldownMinutes', cooldown_mins
  );
end
$function$
;

create or replace function public.book_version()
returns integer
language sql
set search_path to 'public', 'extensions'
as $function$
  select 51
$function$;
