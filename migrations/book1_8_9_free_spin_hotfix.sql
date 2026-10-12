-- Book1 1.8.9 Free Spin hotfix
-- Revert the two-stage pending payout flow.
-- Existing pending prizes are credited once, then new spins pay immediately.
-- The client delays the visible balance instead of delaying the database payout.

do $hotfix$
declare
  d jsonb;
  v int;
  player_name text;
  pending jsonb;
  amt int;
  bal int;
begin
  select data, version into d, v
  from public.book
  where id = 1
  for update;

  d := jsonb_set(d, '{chips}', coalesce(d->'chips','{}'::jsonb), true);
  d := jsonb_set(d, '{log}', coalesce(d->'log','[]'::jsonb), true);

  for player_name, pending in
    select key, value
    from jsonb_each(coalesce(d->'wheelPending','{}'::jsonb))
  loop
    amt := coalesce((pending->>'amount')::int, 0);
    if amt > 0 then
      bal := coalesce((d->'chips'->>player_name)::int, 1000);
      d := jsonb_set(d, array['chips', player_name], to_jsonb(bal + amt), true);
      d := jsonb_set(
        d,
        '{log}',
        (d->'log') || to_jsonb(
          to_char(now() at time zone 'Europe/London','DD Mon HH24:MI')
          || ' ' || player_name || ' received ' || amt
          || ' chips from a recovered pending wheel spin'
        ),
        true
      );
    end if;
  end loop;

  d := jsonb_set(d, '{wheelPending}', '{}'::jsonb, true);

  update public.book
  set data = d, version = v + 1, updated_at = now()
  where id = 1;
end
$hotfix$;

create or replace function public.book_spin_wheel(p_name text, p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $function$
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
$function$;
