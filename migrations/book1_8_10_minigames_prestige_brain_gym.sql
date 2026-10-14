-- Book1 1.8.10 — minigame standings, prestige rewards and Brain Gym
-- Database function version: 33

-- Add Brain Gym XP to the canonical progression calculation.
create or replace function public.book_player_xp(p_data jsonb, p_player text)
returns integer
language plpgsql
stable
set search_path = public, extensions
as $function$
declare
  w jsonb;
  g jsonb;
  xp integer:=0;
  gd integer;
  bd integer;
begin
  for w in select value from jsonb_array_elements(coalesce(p_data->'weeks','[]'::jsonb)) loop
    for g in select value from jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) loop
      if g->>'s1' is null or (g->>'p1'<>p_player and g->>'p2'<>p_player) then continue; end if;
      xp:=xp+100;
      if (((g->>'s1')::int>(g->>'s2')::int and g->>'p1'=p_player) or ((g->>'s2')::int>(g->>'s1')::int and g->>'p2'=p_player)) then xp:=xp+200; end if;
      gd:=case when g->>'p1'=p_player then (g->>'s1')::int-(g->>'s2')::int else (g->>'s2')::int-(g->>'s1')::int end;
      if gd>0 then xp:=xp+gd*10; end if;
    end loop;
  end loop;
  for g in select value from jsonb_array_elements(coalesce(p_data->'connect4','[]'::jsonb)) loop
    if g->>'status' in ('done','draw') and (g->>'challenger'=p_player or g->>'opponent'=p_player) then xp:=xp+50; if g->>'winner'=p_player then xp:=xp+100; end if; end if;
  end loop;
  for g in select value from jsonb_array_elements(coalesce(p_data->'battleships','[]'::jsonb)) loop
    if g->>'status'='done' and (g->>'challenger'=p_player or g->>'opponent'=p_player) then xp:=xp+50; if g->>'winner'=p_player then xp:=xp+100; end if; end if;
  end loop;
  for g in select value from jsonb_array_elements(coalesce(p_data->'hogDuels','[]'::jsonb)) loop
    if g->>'status'='done' and (g->>'challenger'=p_player or g->>'opponent'=p_player) then xp:=xp+25; if g->>'winner'=p_player then xp:=xp+50; end if; end if;
  end loop;
  for g in select value from jsonb_array_elements(coalesce(p_data->'chess','[]'::jsonb)) loop
    if g->>'status' in ('done','draw') and (g->>'challenger'=p_player or g->>'opponent'=p_player) then
      xp:=xp+75; if g->>'winner'=p_player then xp:=xp+150; elsif g->>'status'='draw' then xp:=xp+50; end if;
    end if;
  end loop;
  select coalesce(sum(coalesce((x->>'xp')::int,0)),0)::int into gd
  from jsonb_array_elements(coalesce(p_data->'challengeClaims','[]'::jsonb)) x
  where x->>'player'=p_player;
  select coalesce(sum(coalesce((x->>'xp')::int,0)),0)::int into bd
  from jsonb_array_elements(coalesce(p_data->'brainClaims','[]'::jsonb)) x
  where x->>'player'=p_player;
  return xp+gd+bd;
end
$function$;

-- Patch the existing case-opening RPC without replacing the embedded card catalogue.
do $patch_open_case$
declare
  f text;
  original text;
begin
  select pg_get_functiondef(p.oid) into f
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='book_open_case'
  order by p.oid desc limit 1;

  if f is null then raise exception 'book_open_case not found'; end if;
  original := f;

  f := replace(
    f,
    'already_owned boolean; refund int; dr jsonb;',
    'already_owned boolean; refund int; dr jsonb; prestige int; discount int; dupe_bonus int;'
  );

  f := replace(
    f,
    'cost := coalesce((d->''payouts''->>''caseCost'')::int, 300);',
    'cost := coalesce((d->''payouts''->>''caseCost'')::int, 300);
  prestige := coalesce((d->''progression''->p_name->>''prestige'')::int,0);
  discount := case when prestige>=10 then 30 when prestige>=7 then 25 when prestige>=5 then 20 when prestige>=2 then 10 else 0 end;
  dupe_bonus := case when prestige>=10 then 25 when prestige>=7 then 20 when prestige>=4 then 10 else 0 end;
  cost := greatest(1,floor(cost::numeric*(100-discount)/100)::int);'
  );

  f := replace(
    f,
    'refund := floor(cost * coalesce((dr->>rarity)::numeric, 0) / 100);',
    'refund := floor(cost * least(100,coalesce((dr->>rarity)::numeric, 0)+dupe_bonus) / 100);'
  );

  if f = original
     or position('discount := case when prestige>=10' in f)=0
     or position('dupe_bonus := case when prestige>=10' in f)=0 then
    raise exception 'book_open_case prestige patch incomplete';
  end if;

  execute f;
end
$patch_open_case$;

-- Patch the player action RPC with weekly prestige bonuses and server-validated Brain Gym claims.
do $patch_player_action$
declare
  f text;
  original text;
  brain_branch text;
begin
  select pg_get_functiondef(p.oid) into f
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='book_player_action'
  order by p.oid desc limit 1;

  if f is null then raise exception 'book_player_action not found'; end if;
  original := f;

  f := replace(
    f,
    'wi := (g->>''reward'')::int;',
    's2 := coalesce((d->''progression''->p_name->>''prestige'')::int,0);
    wi := floor((g->>''reward'')::numeric * (100 + case when s2>=10 then 25 when s2>=7 then 20 when s2>=5 then 15 when s2>=3 then 10 else 0 end) / 100)::int;'
  );

  brain_branch := $brain$
elsif t = 'brainClaim' then
    bid := to_char(now() at time zone 'Europe/London','YYYY-MM-DD');
    if p_action->>'day' <> bid then raise exception 'That daily puzzle has rolled over. Refresh Brain Gym.'; end if;
    kind := p_action->>'type';
    if kind not in ('sudoku','crossword','teaser') then raise exception 'Unknown Brain Gym puzzle.'; end if;

    d := jsonb_set(d,'{brainClaims}',coalesce(d->'brainClaims','[]'::jsonb),true);
    if exists (
      select 1 from jsonb_array_elements(d->'brainClaims') x
      where x->>'player'=p_name and x->>'day'=bid and x->>'type'=kind
    ) then raise exception 'Already claimed today.'; end if;

    opp := lower(regexp_replace(coalesce(p_action->>'answer',''),'[^a-zA-Z0-9|]','','g'));
    s2 := (bid::date - date '1970-01-01');

    if kind='sudoku' then
      s1 := 300;
      if opp <> translate(
        '534678912672195348198342567859761423426853791713924856961537284287419635345286179',
        '123456789',
        substring('123456789123456789' from ((s2 % 9)+9)%9 + 1 for 9)
      ) then raise exception 'Not quite. Keep thinking.'; end if;
    elsif kind='crossword' then
      s1 := 250;
      opp := replace(opp,' ','');
      if opp <> case ((s2 % 4)+4)%4
        when 0 then 'ball|area|lead|lady'
        when 1 then 'limb|idea|meal|ball'
        when 2 then 'salt|area|lean|tank'
        else 'care|area|rear|earl'
      end then raise exception 'Not quite. Keep thinking.'; end if;
    else
      s1 := 150;
      if not (
        (((s2 % 7)+7)%7=0 and opp='towel') or
        (((s2 % 7)+7)%7=1 and opp='stamp') or
        (((s2 % 7)+7)%7=2 and opp='map') or
        (((s2 % 7)+7)%7=3 and opp='bottle') or
        (((s2 % 7)+7)%7=4 and opp in ('m','letterm')) or
        (((s2 % 7)+7)%7=5 and opp='keyboard') or
        (((s2 % 7)+7)%7=6 and opp='echo')
      ) then raise exception 'Not quite. Keep thinking.'; end if;
    end if;

    d := jsonb_set(d,'{brainClaims}',(d->'brainClaims') || jsonb_build_array(jsonb_build_object(
      'player',p_name,'day',bid,'type',kind,'xp',s1,'at',(extract(epoch from now())*1000)::bigint
    )),true);

    if (
      select count(distinct x->>'type')
      from jsonb_array_elements(d->'brainClaims') x
      where x->>'player'=p_name and x->>'day'=bid and x->>'type' in ('sudoku','crossword','teaser')
    ) = 3 and not exists (
      select 1 from jsonb_array_elements(d->'brainClaims') x
      where x->>'player'=p_name and x->>'day'=bid and x->>'type'='daily'
    ) then
      d := jsonb_set(d,'{brainClaims}',(d->'brainClaims') || jsonb_build_array(jsonb_build_object(
        'player',p_name,'day',bid,'type','daily','xp',200,'at',(extract(epoch from now())*1000)::bigint
      )),true);
      d := jsonb_set(d,'{log}',(d->'log') || to_jsonb(format('%s cleared the full Brain Gym for %s (+200 XP bonus)',p_name,bid)));
    end if;

    d := jsonb_set(d,'{log}',(d->'log') || to_jsonb(format('%s completed %s in Brain Gym (+%s XP)',p_name,kind,s1)));

  $brain$;

  if position('elsif t = ''prestige'' then' in f)=0 then raise exception 'prestige branch not found'; end if;
  f := replace(f, 'elsif t = ''prestige'' then', brain_branch || 'elsif t = ''prestige'' then');

  if f = original
     or position('brainClaim' in f)=0
     or position('weekly challenge' in f)=0
     or position('case when s2>=10 then 25' in f)=0 then
    raise exception 'book_player_action 1.8.10 patch incomplete';
  end if;

  execute f;
end
$patch_player_action$;

-- Keep the state shape explicit for clients loading old data.
update public.book
set data = jsonb_set(data,'{brainClaims}',coalesce(data->'brainClaims','[]'::jsonb),true),
    updated_at = now()
where id=1;

create or replace function public.book_version()
returns integer
language sql
set search_path = public, extensions
as $function$
  select 33
$function$;
