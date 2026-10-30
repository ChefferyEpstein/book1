CREATE OR REPLACE FUNCTION public.book_pinball_finish(p_name text, p_pin text, p_token text, p_score integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare d jsonb; v int; i int; sess jsonb; elapsed bigint; prize int; balance int; rec jsonb; wn int;
begin
  if public.book_check(p_name,p_pin) is null then raise exception 'Wrong name or PIN'; end if;
  if p_score is null or p_score<0 or p_score>8000 then raise exception 'Invalid Pinball score.'; end if;
  select data,version into d,v from public.book where id=1 for update;
  i:=null;
  for rec in select value from jsonb_array_elements(coalesce(d->'pinballSessions','[]'::jsonb)) with ordinality as x(value,ord) loop
    if rec->>'token'=p_token and rec->>'player'=p_name and rec->>'status'='playing' then
      i:=(select ord::int-1 from jsonb_array_elements(coalesce(d->'pinballSessions','[]'::jsonb)) with ordinality as z(value,ord) where value=rec limit 1);
      sess:=rec;
      exit;
    end if;
  end loop;
  if i is null or sess is null then raise exception 'That Pinball game has already finished or is invalid.'; end if;
  elapsed:=(extract(epoch from clock_timestamp())*1000)::bigint-(sess->>'startedAt')::bigint;
  if elapsed<15000 then raise exception 'Play for at least 15 seconds before submitting a score.'; end if;
  if p_score>greatest(250,floor((elapsed::numeric/1000)*180)::int) then raise exception 'That score is too high for the time played.'; end if;
  prize:=case when p_score<500 then 0 when p_score<1000 then 250 when p_score<2000 then 625 when p_score<3500 then 1250 when p_score<5000 then 2500 else 5000 end;
  balance:=coalesce((d->'chips'->>p_name)::int,1000);
  wn:=(sess->>'week')::int;
  d:=jsonb_set(d,array['pinballSessions',i::text],sess||jsonb_build_object('status','finished','score',p_score,'prize',prize,'finishedAt',(extract(epoch from clock_timestamp())*1000)::bigint),true);
  d:=jsonb_set(d,'{chips}',coalesce(d->'chips','{}'::jsonb),true);
  d:=jsonb_set(d,array['chips',p_name],to_jsonb(balance+prize),true);
  d:=jsonb_set(d,'{pinballScores}',coalesce(d->'pinballScores','[]'::jsonb)||jsonb_build_array(jsonb_build_object(
    'player',p_name,'score',p_score,'prize',prize,'week',wn,'at',(extract(epoch from clock_timestamp())*1000)::bigint
  )),true);
  d:=jsonb_set(d,'{log}',coalesce(d->'log','[]'::jsonb)||to_jsonb(format('%s scored %s on Pinball and won %s chips',p_name,p_score,prize)),true);
  update public.book set data=d,version=v+1,updated_at=now() where id=1;
  return jsonb_build_object('score',p_score,'prize',prize,'balance',balance+prize,'version',v+1);
end
$function$;

CREATE OR REPLACE FUNCTION public.book_version()
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
  select 42;
$function$;
