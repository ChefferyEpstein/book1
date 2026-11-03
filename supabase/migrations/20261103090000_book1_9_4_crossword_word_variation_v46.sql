create or replace function public.book_brain_crossword_claim(p_name text, p_pin text, p_day text, p_answer text)
 returns integer
 language plpgsql
 security definer
 set search_path to 'public', 'extensions'
as $function$
declare
  d jsonb;
  v int;
  day_key text;
  answer_norm text;
  expected_answer text;
  full_count int;
  crossword_answers text[] := array[
    'wall|area|lead|lady',
    'bare|area|rear|ears',
    'care|area|rear|ears',
    'dare|area|rear|ears',
    'fare|area|rear|ears',
    'hare|area|rear|ears',
    'mare|area|rear|ears',
    'pare|area|rear|ears',
    'rare|area|rear|ears',
    'ware|area|rear|ears',
    'warm|area|rear|mars',
    'farm|area|rear|mars',
    'love|oven|vend|ends'
  ];
begin
  if public.book_check(p_name, p_pin) is null then
    raise exception 'Wrong name or PIN';
  end if;

  select data, version into d, v from public.book where id = 1 for update;
  day_key := to_char(now() at time zone 'Europe/London', 'YYYY-MM-DD');
  if p_day is distinct from day_key then
    raise exception 'That daily puzzle has rolled over. Refresh Brain Gym.';
  end if;

  d := jsonb_set(d, '{brainClaims}', coalesce(d->'brainClaims', '[]'::jsonb), true);
  if exists (
    select 1 from jsonb_array_elements(d->'brainClaims') x
    where x->>'player' = p_name and x->>'day' = day_key and x->>'type' = 'crossword'
  ) then
    raise exception 'Already claimed today.';
  end if;

  expected_answer := crossword_answers[mod((day_key::date - date '1970-01-01'), array_length(crossword_answers, 1)) + 1];
  answer_norm := lower(regexp_replace(coalesce(p_answer, ''), '[^a-zA-Z0-9|]', '', 'g'));
  if answer_norm <> expected_answer then
    raise exception 'Not quite. Keep thinking.';
  end if;

  d := jsonb_set(d, '{brainClaims}', (d->'brainClaims') || jsonb_build_array(jsonb_build_object(
    'player', p_name, 'day', day_key, 'type', 'crossword', 'xp', 250,
    'at', (extract(epoch from now()) * 1000)::bigint
  )), true);

  select count(distinct x->>'type')::int into full_count
  from jsonb_array_elements(d->'brainClaims') x
  where x->>'player' = p_name and x->>'day' = day_key
    and x->>'type' in ('sudoku', 'crossword', 'teaser');

  if full_count = 3 and not exists (
    select 1 from jsonb_array_elements(d->'brainClaims') x
    where x->>'player' = p_name and x->>'day' = day_key and x->>'type' = 'daily'
  ) then
    d := jsonb_set(d, '{brainClaims}', (d->'brainClaims') || jsonb_build_array(jsonb_build_object(
      'player', p_name, 'day', day_key, 'type', 'daily', 'xp', 200,
      'at', (extract(epoch from now()) * 1000)::bigint
    )), true);
    d := jsonb_set(d, '{log}', coalesce(d->'log', '[]'::jsonb) ||
      to_jsonb(format('%s cleared the full Brain Gym for %s (+200 XP bonus)', p_name, day_key)), true);
  end if;

  d := jsonb_set(d, '{log}', coalesce(d->'log', '[]'::jsonb) ||
    to_jsonb(format('%s completed crossword in Brain Gym (+250 XP)', p_name)), true);
  update public.book set data = d, version = v + 1, updated_at = now() where id = 1;
  return v + 1;
end
$function$;

create or replace function public.book_version()
 returns integer
 language sql
 stable
 set search_path to 'public', 'extensions'
as $function$
  select 46;
$function$;
