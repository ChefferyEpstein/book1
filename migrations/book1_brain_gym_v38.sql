-- Book1 Brain Gym refresh — DB v38
-- 6x6 mini Sudoku + expanded daily mini-crossword rotation.

begin;

create or replace function public.book_brain_claim(
  p_name text,
  p_pin text,
  p_type text,
  p_day text,
  p_answer text
)
returns integer
language plpgsql
security definer
set search_path = public, extensions
as $function$
declare
  d jsonb;
  v int;
  day_key text;
  answer_norm text;
  day_no int;
  xp_award int;
  expected text;
  full_count int;
begin
  if public.book_check(p_name,p_pin) is null then raise exception 'Wrong name or PIN'; end if;

  select data,version into d,v
  from public.book
  where id=1
  for update;

  day_key := to_char(now() at time zone 'Europe/London','YYYY-MM-DD');
  if p_day is distinct from day_key then
    raise exception 'That daily puzzle has rolled over. Refresh Brain Gym.';
  end if;
  if p_type not in ('sudoku','crossword','teaser') then
    raise exception 'Unknown Brain Gym puzzle.';
  end if;

  d := jsonb_set(d,'{brainClaims}',coalesce(d->'brainClaims','[]'::jsonb),true);
  if exists (
    select 1
    from jsonb_array_elements(d->'brainClaims') x
    where x->>'player'=p_name and x->>'day'=day_key and x->>'type'=p_type
  ) then
    raise exception 'Already claimed today.';
  end if;

  answer_norm := lower(regexp_replace(coalesce(p_answer,''),'[^a-zA-Z0-9|]','','g'));
  day_no := day_key::date - date '1970-01-01';

  if p_type='sudoku' then
    xp_award := 300;
    expected := translate(
      '123456456123234561561234345612612345',
      '123456',
      substring('123456123456' from (((day_no % 6)+6)%6)+1 for 6)
    );
    if answer_norm <> expected then raise exception 'Not quite. Keep thinking.'; end if;

  elsif p_type='crossword' then
    xp_award := 250;
    expected := case (((day_no % 16)+16)%16)
      when 0 then 'ball|area|lead|lady'
      when 1 then 'limb|idea|meal|ball'
      when 2 then 'salt|area|lean|tank'
      when 3 then 'care|area|rear|earl'
      when 4 then 'late|area|tear|earn'
      when 5 then 'sand|area|near|dart'
      when 6 then 'bite|idea|tear|earn'
      when 7 then 'tape|area|pear|earn'
      when 8 then 'card|area|rear|dart'
      when 9 then 'mate|area|tear|earn'
      when 10 then 'bind|idea|near|dart'
      when 11 then 'bill|idea|lead|lady'
      when 12 then 'bird|idea|rear|dart'
      when 13 then 'park|area|rear|kart'
      when 14 then 'cart|area|rear|tart'
      else 'hard|area|rear|dart'
    end;
    if answer_norm <> expected then raise exception 'Not quite. Keep thinking.'; end if;

  else
    xp_award := 150;
    expected := case (((day_no % 7)+7)%7)
      when 0 then 'towel'
      when 1 then 'stamp'
      when 2 then 'map'
      when 3 then 'bottle'
      when 4 then 'm'
      when 5 then 'keyboard'
      else 'echo'
    end;
    if (((day_no % 7)+7)%7)=4 then
      if answer_norm not in ('m','letterm') then raise exception 'Not quite. Keep thinking.'; end if;
    elsif answer_norm <> expected then
      raise exception 'Not quite. Keep thinking.';
    end if;
  end if;

  d := jsonb_set(d,'{brainClaims}',(d->'brainClaims') || jsonb_build_array(jsonb_build_object(
    'player',p_name,'day',day_key,'type',p_type,'xp',xp_award,'at',(extract(epoch from now())*1000)::bigint
  )),true);

  select count(distinct x->>'type')::int into full_count
  from jsonb_array_elements(d->'brainClaims') x
  where x->>'player'=p_name and x->>'day'=day_key and x->>'type' in ('sudoku','crossword','teaser');

  if full_count=3 and not exists (
    select 1 from jsonb_array_elements(d->'brainClaims') x
    where x->>'player'=p_name and x->>'day'=day_key and x->>'type'='daily'
  ) then
    d := jsonb_set(d,'{brainClaims}',(d->'brainClaims') || jsonb_build_array(jsonb_build_object(
      'player',p_name,'day',day_key,'type','daily','xp',200,'at',(extract(epoch from now())*1000)::bigint
    )),true);
    d := jsonb_set(d,'{log}',coalesce(d->'log','[]'::jsonb) || to_jsonb(format('%s cleared the full Brain Gym for %s (+200 XP bonus)',p_name,day_key)),true);
  end if;

  d := jsonb_set(d,'{log}',coalesce(d->'log','[]'::jsonb) || to_jsonb(format('%s completed %s in Brain Gym (+%s XP)',p_name,p_type,xp_award)),true);

  update public.book
  set data=d,version=v+1,updated_at=now()
  where id=1;

  return v+1;
end
$function$;

create or replace function public.book_version()
returns integer
language sql
set search_path = public, extensions
as $function$
  select 38
$function$;

commit;

select public.book_version() as version;
