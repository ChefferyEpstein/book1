-- Pinball sessions expire after the fixed 45-second game window.
-- Leaving the Pinball tab does not abandon the session; it remains reserved
-- until the server-side expiry is reached. A short finish grace handles latency.

create or replace function public.book_pinball_start(p_name text, p_pin text)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
declare
  d jsonb;
  v int;
  balance int;
  token text;
  wn int;
  now_ms bigint;
  sessions jsonb;
begin
  if public.book_check(p_name,p_pin) is null then raise exception 'Wrong name or PIN'; end if;
  select data,version into d,v from public.book where id=1 for update;
  now_ms := (extract(epoch from clock_timestamp())*1000)::bigint;

  select coalesce(jsonb_agg(
    case when x.value->>'status'='playing'
      and now_ms-coalesce((x.value->>'startedAt')::bigint,0)>=45000
      then x.value||jsonb_build_object('status','expired','expiredAt',now_ms,'expireReason','time limit reached')
      else x.value end
    order by x.ord
  ),'[]'::jsonb)
  into sessions
  from jsonb_array_elements(coalesce(d->'pinballSessions','[]'::jsonb)) with ordinality as x(value,ord);
  d := jsonb_set(d,'{pinballSessions}',sessions,true);

  if exists(select 1 from jsonb_array_elements(coalesce(d->'pinballSessions','[]'::jsonb)) x
    where x->>'player'=p_name and x->>'status'='playing') then
    raise exception 'Your Pinball game is still in progress. It expires after 45 seconds.';
  end if;

  balance := coalesce((d->'chips'->>p_name)::int,1000);
  if balance<100 then raise exception 'You need 100 chips to play Pinball.'; end if;
  wn := (d->'weeks'->(jsonb_array_length(d->'weeks')-1)->>'n')::int;
  token := md5(random()::text||clock_timestamp()::text||p_name);

  d := jsonb_set(d,'{chips}',coalesce(d->'chips','{}'::jsonb),true);
  d := jsonb_set(d,array['chips',p_name],to_jsonb(balance-100),true);
  d := jsonb_set(d,'{pinballSessions}',coalesce(d->'pinballSessions','[]'::jsonb)||jsonb_build_array(jsonb_build_object(
    'token',token,'player',p_name,'status','playing','week',wn,'startedAt',now_ms
  )),true);
  d := jsonb_set(d,'{log}',coalesce(d->'log','[]'::jsonb)||to_jsonb(format('%s paid 100 chips to play Pinball',p_name)),true);
  update public.book set data=d,version=v+1,updated_at=now() where id=1;
  return jsonb_build_object('token',token,'version',v+1);
end
$function$;

create or replace function public.book_pinball_finish(p_name text, p_pin text, p_token text, p_score integer)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'extensions'
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
  wn int;
  now_ms bigint;
begin
  if public.book_check(p_name,p_pin) is null then raise exception 'Wrong name or PIN'; end if;
  if p_score is null or p_score<0 or p_score>8000 then raise exception 'Invalid Pinball score.'; end if;
  select data,version into d,v from public.book where id=1 for update;
  now_ms := (extract(epoch from clock_timestamp())*1000)::bigint;
  i := null;

  for rec in select value from jsonb_array_elements(coalesce(d->'pinballSessions','[]'::jsonb)) with ordinality as x(value,ord)
  loop
    if rec->>'token'=p_token and rec->>'player'=p_name and rec->>'status'='playing' then
      i := (select ord::int-1 from jsonb_array_elements(coalesce(d->'pinballSessions','[]'::jsonb)) with ordinality as z(value,ord)
        where value=rec limit 1);
      sess := rec;
      exit;
    end if;
  end loop;
  if i is null or sess is null then raise exception 'That Pinball game has already finished or is invalid.'; end if;

  elapsed := now_ms-(sess->>'startedAt')::bigint;
  if elapsed>60000 then
    d := jsonb_set(d,array['pinballSessions',i::text],
      sess||jsonb_build_object('status','expired','expiredAt',now_ms,'expireReason','time limit reached'),true);
    update public.book set data=d,version=v+1,updated_at=now() where id=1;
    return jsonb_build_object('expired',true,'version',v+1);
  end if;
  if elapsed<15000 then raise exception 'Play for at least 15 seconds before submitting a score.'; end if;
  if p_score>greatest(250,floor((elapsed::numeric/1000)*180)::int) then raise exception 'That score is too high for the time played.'; end if;

  prize := case when p_score<500 then 0 when p_score<1000 then 250 when p_score<2000 then 625 when p_score<3500 then 1250 when p_score<5000 then 2500 else 5000 end;
  balance := coalesce((d->'chips'->>p_name)::int,1000);
  wn := (sess->>'week')::int;
  d := jsonb_set(d,array['pinballSessions',i::text],sess||jsonb_build_object('status','finished','score',p_score,'prize',prize,'finishedAt',now_ms),true);
  d := jsonb_set(d,'{chips}',coalesce(d->'chips','{}'::jsonb),true);
  d := jsonb_set(d,array['chips',p_name],to_jsonb(balance+prize),true);
  d := jsonb_set(d,'{pinballScores}',coalesce(d->'pinballScores','[]'::jsonb)||jsonb_build_array(jsonb_build_object(
    'player',p_name,'score',p_score,'prize',prize,'week',wn,'at',now_ms
  )),true);
  d := jsonb_set(d,'{log}',coalesce(d->'log','[]'::jsonb)||to_jsonb(format('%s scored %s on Pinball and won %s chips',p_name,p_score,prize)),true);
  update public.book set data=d,version=v+1,updated_at=now() where id=1;
  return jsonb_build_object('score',p_score,'prize',prize,'balance',balance+prize,'version',v+1);
end
$function$;

revoke all on function public.book_pinball_start(text,text) from public;
revoke all on function public.book_pinball_finish(text,text,text,integer) from public;
grant execute on function public.book_pinball_start(text,text) to anon, authenticated;
grant execute on function public.book_pinball_finish(text,text,text,integer) to anon, authenticated;
