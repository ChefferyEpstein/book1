CREATE OR REPLACE FUNCTION public.book_brain_claim(p_name text, p_pin text, p_type text, p_day text, p_answer text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare d jsonb; v int; day_key text; answer_norm text; day_no int; xp_award int; expected text; full_count int;
begin
 if public.book_check(p_name,p_pin) is null then raise exception 'Wrong name or PIN'; end if;
 select data,version into d,v from public.book where id=1 for update;
 day_key:=to_char(now() at time zone 'Europe/London','YYYY-MM-DD');
 if p_day is distinct from day_key then raise exception 'That daily puzzle has rolled over. Refresh Brain Gym.'; end if;
 if p_type not in ('sudoku','crossword','teaser') then raise exception 'Unknown Brain Gym puzzle.'; end if;
 d:=jsonb_set(d,'{brainClaims}',coalesce(d->'brainClaims','[]'::jsonb),true);
 if exists(select 1 from jsonb_array_elements(d->'brainClaims') x where x->>'player'=p_name and x->>'day'=day_key and x->>'type'=p_type) then raise exception 'Already claimed today.'; end if;
 answer_norm:=lower(regexp_replace(coalesce(p_answer,''),'[^a-zA-Z0-9|]','','g'));
 day_no:=day_key::date-date '1970-01-01';
 if p_type='sudoku' then
  xp_award:=300;
  expected:=translate('123456456123234561561234345612612345','123456',substring('123456123456' from (((day_no % 6)+6)%6)+1 for 6));
  if answer_norm<>expected then raise exception 'Not quite. Keep thinking.'; end if;
 elsif p_type='crossword' then
  xp_award:=250;
  expected:=case (day_no % 30)
      when 0 then 'ball|cue|rack|poke'
      when 1 then 'lion|bear|wolf|deer'
      when 2 then 'mint|sage|thym|basi'
      when 3 then 'mars|venu|moon|star'
      when 4 then 'jazz|rock|soul|folk'
      when 5 then 'fork|knif|spoo|plat'
      when 6 then 'lime|pear|plum|kiwi'
      when 7 then 'gold|silv|iron|lead'
      when 8 then 'hats|coat|boot|scar'
      when 9 then 'rose|lily|iris|dais'
      when 10 then 'ship|boat|sail|mast'
      when 11 then 'math|read|play|draw'
      when 12 then 'blue|pink|gold|teal'
      when 13 then 'ring|bell|tone|echo'
      when 14 then 'fish|crab|seal|ottr'
      when 15 then 'camp|tent|fire|hike'
      when 16 then 'cake|tart|pies|flan'
      when 17 then 'wind|rain|snow|hail'
      when 18 then 'king|quee|rook|pawn'
      when 19 then 'fast|slow|quic|rush'
      when 20 then 'bark|leaf|root|seed'
      when 21 then 'soap|towe|bath|wash'
      when 22 then 'grid|code|data|byte'
      when 23 then 'beer|wine|cide|ale'
      when 24 then 'nose|ears|eyes|lips'
      when 25 then 'gate|door|wall|roof'
      when 26 then 'fame|fort|luck|hope'
      when 27 then 'mile|yard|foot|inch'
      when 28 then 'bass|drum|pian|harp'
      when 29 then 'zero|ones|tens|doze'
  end;
  if answer_norm<>expected then raise exception 'Not quite. Keep thinking.'; end if;
 else
  xp_award:=150;
  if (day_no % 25)=0 then
    if answer_norm not in ('towel') then raise exception 'Not quite. Keep thinking.'; end if;
  elsif (day_no % 25)=1 then
    if answer_norm not in ('stamp') then raise exception 'Not quite. Keep thinking.'; end if;
  elsif (day_no % 25)=2 then
    if answer_norm not in ('map') then raise exception 'Not quite. Keep thinking.'; end if;
  elsif (day_no % 25)=3 then
    if answer_norm not in ('bottle') then raise exception 'Not quite. Keep thinking.'; end if;
  elsif (day_no % 25)=4 then
    if answer_norm not in ('m','letterm') then raise exception 'Not quite. Keep thinking.'; end if;
  elsif (day_no % 25)=5 then
    if answer_norm not in ('keyboard') then raise exception 'Not quite. Keep thinking.'; end if;
  elsif (day_no % 25)=6 then
    if answer_norm not in ('echo') then raise exception 'Not quite. Keep thinking.'; end if;
  elsif (day_no % 25)=7 then
    if answer_norm not in ('sponge') then raise exception 'Not quite. Keep thinking.'; end if;
  elsif (day_no % 25)=8 then
    if answer_norm not in ('needle') then raise exception 'Not quite. Keep thinking.'; end if;
  elsif (day_no % 25)=9 then
    if answer_norm not in ('age') then raise exception 'Not quite. Keep thinking.'; end if;
  elsif (day_no % 25)=10 then
    if answer_norm not in ('clock') then raise exception 'Not quite. Keep thinking.'; end if;
  elsif (day_no % 25)=11 then
    if answer_norm not in ('cold') then raise exception 'Not quite. Keep thinking.'; end if;
  elsif (day_no % 25)=12 then
    if answer_norm not in ('phone','telephone') then raise exception 'Not quite. Keep thinking.'; end if;
  elsif (day_no % 25)=13 then
    if answer_norm not in ('table','chair') then raise exception 'Not quite. Keep thinking.'; end if;
  elsif (day_no % 25)=14 then
    if answer_norm not in ('footsteps','steps') then raise exception 'Not quite. Keep thinking.'; end if;
  elsif (day_no % 25)=15 then
    if answer_norm not in ('name') then raise exception 'Not quite. Keep thinking.'; end if;
  elsif (day_no % 25)=16 then
    if answer_norm not in ('book') then raise exception 'Not quite. Keep thinking.'; end if;
  elsif (day_no % 25)=17 then
    if answer_norm not in ('river') then raise exception 'Not quite. Keep thinking.'; end if;
  elsif (day_no % 25)=18 then
    if answer_norm not in ('light') then raise exception 'Not quite. Keep thinking.'; end if;
  elsif (day_no % 25)=19 then
    if answer_norm not in ('glove') then raise exception 'Not quite. Keep thinking.'; end if;
  elsif (day_no % 25)=20 then
    if answer_norm not in ('teapot') then raise exception 'Not quite. Keep thinking.'; end if;
  elsif (day_no % 25)=21 then
    if answer_norm not in ('future') then raise exception 'Not quite. Keep thinking.'; end if;
  elsif (day_no % 25)=22 then
    if answer_norm not in ('deck','deckofcards') then raise exception 'Not quite. Keep thinking.'; end if;
  elsif (day_no % 25)=23 then
    if answer_norm not in ('road') then raise exception 'Not quite. Keep thinking.'; end if;
  elsif (day_no % 25)=24 then
    if answer_norm not in ('coin') then raise exception 'Not quite. Keep thinking.'; end if;
  end if;
 end if;
 d:=jsonb_set(d,'{brainClaims}',(d->'brainClaims')||jsonb_build_array(jsonb_build_object('player',p_name,'day',day_key,'type',p_type,'xp',xp_award,'at',(extract(epoch from now())*1000)::bigint)),true);
 select count(distinct x->>'type')::int into full_count from jsonb_array_elements(d->'brainClaims') x where x->>'player'=p_name and x->>'day'=day_key and x->>'type' in ('sudoku','crossword','teaser');
 if full_count=3 and not exists(select 1 from jsonb_array_elements(d->'brainClaims') x where x->>'player'=p_name and x->>'day'=day_key and x->>'type'='daily') then
  d:=jsonb_set(d,'{brainClaims}',(d->'brainClaims')||jsonb_build_array(jsonb_build_object('player',p_name,'day',day_key,'type','daily','xp',200,'at',(extract(epoch from now())*1000)::bigint)),true);
  d:=jsonb_set(d,'{log}',coalesce(d->'log','[]'::jsonb)||to_jsonb(format('%s cleared the full Brain Gym for %s (+200 XP bonus)',p_name,day_key)),true);
 end if;
 d:=jsonb_set(d,'{log}',coalesce(d->'log','[]'::jsonb)||to_jsonb(format('%s completed %s in Brain Gym (+%s XP)',p_name,p_type,xp_award)),true);
 update public.book set data=d,version=v+1,updated_at=now() where id=1;
 return v+1;
end
$function$
