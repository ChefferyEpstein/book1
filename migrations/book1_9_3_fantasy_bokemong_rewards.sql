-- Book1.9.3 — fantasy captains/jackpot and Bokémong team/reward progression
-- Database function version: 39
-- Run in the Supabase SQL editor after deploying the matching client.
begin;

-- Keep fantasy picks on the existing PIN-authenticated, row-locked player RPC.
do $migration$
declare
  fn_def text;
  needle text := 'g := jsonb_set(g,array[''picks'',p_name],p_action->''picks'',true);';
  replacement text;
begin
  fn_def := pg_get_functiondef('public.book_player_action(text,text,jsonb)'::regprocedure);
  if position('captains' in fn_def)=0 then
    if position(needle in fn_def)=0 then
      raise exception 'Book1.9.3: could not find the existing fantasy-pick write in book_player_action.';
    end if;
    replacement := needle || E'
    if not ((p_action->''picks'') ? coalesce(p_action->>''captain'',p_action->''picks''->>0)) then
      raise exception ''Captain must be one of your four fantasy picks.'';
    end if;
    g := jsonb_set(g,''{captains}'',coalesce(g->''captains'',''{}''::jsonb),true);
    g := jsonb_set(g,array[''captains'',p_name],to_jsonb(coalesce(p_action->>''captain'',p_action->''picks''->>0)),true);';
    fn_def := replace(fn_def,needle,replacement);
    execute fn_def;
  end if;
end
$migration$;

create or replace function public.book_bokemong_reward_193(p_data jsonb,p_winner text,p_now_ms bigint)
returns jsonb
language plpgsql
set search_path = public, extensions
as $function$
declare
  bp jsonb;
  wins_today integer := 0;
  chips_now integer;
  unlock_id text;
  candidate text;
  candidates text[] := array[
    'rack-beast','pocket-wyrm','arcade-gremlin','grid-fiend','bishop-bastard',
    'hr-parasite','connectivore','bookie-rat','kitchen-ogre','mong','pub-lich',
    'table-tyrant','grind-goblin','spreadsheet-necromancer','regime-hound'
  ];
begin
  bp := p_data->'bokemongs'->'players'->p_winner;
  if bp is null then return p_data; end if;

  select count(*)::integer into wins_today
  from jsonb_array_elements(coalesce(p_data#>'{bokemongs,battles}','[]'::jsonb)) x
  where x->>'status'='done'
    and x->>'winner'=p_winner
    and coalesce((x->>'completedAt')::bigint,0) >= p_now_ms-86400000;

  if wins_today >= 3 then
    bp := jsonb_set(bp,'{lastReward}',jsonb_build_object(
      'chips',0,'mong',null,'at',p_now_ms,'note','Daily reward cap reached'
    ),true);
    return jsonb_set(p_data,array['bokemongs','players',p_winner],bp,true);
  end if;

  p_data := jsonb_set(p_data,'{chips}',coalesce(p_data->'chips','{}'::jsonb),true);
  chips_now := coalesce((p_data->'chips'->>p_winner)::integer,1000);
  p_data := jsonb_set(p_data,array['chips',p_winner],to_jsonb(chips_now+5000),true);

  foreach candidate in array candidates loop
    if not exists (
      select 1 from jsonb_array_elements(coalesce(bp->'owned','[]'::jsonb)) owned
      where coalesce(owned->>'id',owned#>>'{}')=candidate
    ) then
      unlock_id := candidate;
      exit;
    end if;
  end loop;

  if unlock_id is not null then
    bp := jsonb_set(bp,'{owned}',coalesce(bp->'owned','[]'::jsonb)||jsonb_build_array(
      jsonb_build_object('id',unlock_id,'acquiredAt',p_now_ms,'source','battle-reward')
    ),true);
  end if;
  bp := jsonb_set(bp,'{lastReward}',jsonb_build_object(
    'chips',5000,'mong',unlock_id,'at',p_now_ms,'note','Battle victory'
  ),true);
  p_data := jsonb_set(p_data,array['bokemongs','players',p_winner],bp,true);
  p_data := jsonb_set(p_data,'{log}',coalesce(p_data->'log','[]'::jsonb)||jsonb_build_array(
    p_winner||' earned 5,000 chips for a Bokémong victory'||
    case when unlock_id is null then '' else ' and unlocked '||unlock_id end
  ),true);
  return p_data;
end
$function$;

revoke all on function public.book_bokemong_reward_193(jsonb,text,bigint) from public;
revoke all on function public.book_bokemong_reward_193(jsonb,text,bigint) from anon, authenticated;

-- Extend the existing battle RPC in place, preserving its PIN check, row lock,
-- turn logic, and existing grants.
do $migration$
declare
  fn_def text;
  needle text;
  replacement text;
begin
  fn_def := pg_get_functiondef('public.book_bokemong_action(text,text,jsonb)'::regprocedure);

  if position('bokemongTeam' in fn_def)=0 then
    needle := 'if t=''bokemongChallenge'' then';
    if position(needle in fn_def)=0 then
      raise exception 'Book1.9.3: could not find the Bokémong challenge branch.';
    end if;
    replacement := $patch$if t='bokemongTeam' then
    bp:=d->'bokemongs'->'players'->p_name;
    if bp is null then raise exception 'Choose a Bokémong starter first'; end if;
    if p_action->'team' is null or jsonb_typeof(p_action->'team') is distinct from 'array' then
      raise exception 'Choose exactly three owned Bokémongs';
    end if;
    if jsonb_array_length(p_action->'team')<>3 then raise exception 'Choose exactly three owned Bokémongs'; end if;
    select count(distinct value)::integer into acc from jsonb_array_elements_text(p_action->'team');
    if acc<>3 then raise exception 'Your team must contain three different Bokémongs'; end if;
    if exists(
      select 1 from jsonb_array_elements_text(p_action->'team') picked
      where not exists(
        select 1 from jsonb_array_elements(coalesce(bp->'owned','[]'::jsonb)) owned
        where coalesce(owned->>'id',owned#>>'{}')=picked.value
      )
    ) then raise exception 'You can only field Bokémongs you own'; end if;
    if exists(
      select 1 from jsonb_array_elements(d->'bokemongs'->'battles') battle
      where battle->>'status' in ('pending','playing')
        and (battle->>'a'=p_name or battle->>'b'=p_name)
    ) then raise exception 'Finish or recall your open challenge before changing team'; end if;
    bp:=jsonb_set(bp,'{team}',p_action->'team',true);
    d:=jsonb_set(d,array['bokemongs','players',p_name],bp,true);

  elsif t='bokemongChallenge' then$patch$;
    fn_def := replace(fn_def,needle,replacement);
  end if;

  -- The recall button already exists in the client; ensure the server supports it.
  if position('elsif t=''bokemongRecall'' then' in fn_def)=0 then
    needle := 'elsif t in (''bokemongAccept'',''bokemongDecline'',''bokemongMove'',''bokemongForfeit'') then';
    if position(needle in fn_def)>0 then
      fn_def := replace(fn_def,needle,
        'elsif t in (''bokemongAccept'',''bokemongDecline'',''bokemongRecall'',''bokemongMove'',''bokemongForfeit'') then');
    end if;
    needle := 'elsif t=''bokemongForfeit'' then';
    if position(needle in fn_def)>0 then
      replacement := $patch$elsif t='bokemongRecall' then
      if g->>'status'<>'pending' then raise exception 'That challenge is no longer pending'; end if;
      if g->>'a'<>p_name then raise exception 'Only the challenger can recall this challenge'; end if;
      g:=g||jsonb_build_object('status','declined','completedAt',now_ms,'resultReason','recalled');
      g:=jsonb_set(g,'{log}',coalesce(g->'log','[]'::jsonb)||jsonb_build_array(p_name||' recalled the challenge.'),true);

    elsif t='bokemongForfeit' then$patch$;
      fn_def := replace(fn_def,needle,replacement);
    end if;
  end if;

  if position('book_bokemong_reward_193' in fn_def)=0 then
    needle := 'd:=jsonb_set(d,array[''bokemongs'',''battles'',idx::text],g,true);';
    if position(needle in fn_def)=0 then
      raise exception 'Book1.9.3: could not find the Bokémong battle save point.';
    end if;
    replacement := $patch$if g->>'status'='done' and g->>'winner' is not null and not coalesce((g->>'rewarded')::boolean,false) then
      d:=public.book_bokemong_reward_193(d,g->>'winner',now_ms);
      g:=g||jsonb_build_object('rewarded',true);
    end if;
    d:=jsonb_set(d,array['bokemongs','battles',idx::text],g,true);$patch$;
    fn_def := replace(fn_def,needle,replacement);
  end if;

  execute fn_def;
end
$migration$;

-- Keep the SQL type/power maps aligned with the client Bokedex.
do $migration$
declare fn_def text;
begin
  fn_def := pg_get_functiondef('public.book_bokemong_type_191(text)'::regprocedure);
  if position('when ''bookie-rat'' then ''Pub''' in fn_def)=0 then
    fn_def := replace(fn_def,'when ''pub-lich'' then ''Pub''',
      'when ''pub-lich'' then ''Pub'''||E'\n    when ''bookie-rat'' then ''Pub''');
    execute fn_def;
  end if;

  fn_def := pg_get_functiondef('public.book_bokemong_power_190(text)'::regprocedure);
  if position('when ''bookie-rat'' then 46' in fn_def)=0 then
    fn_def := replace(fn_def,'when ''pub-lich'' then 68 when ''rave-mite'' then 46 when ''kitchen-ogre'' then 75',
      'when ''pub-lich'' then 68 when ''rave-mite'' then 46 when ''bookie-rat'' then 46 when ''kitchen-ogre'' then 75');
    execute fn_def;
  end if;

  -- Complete the reciprocal resistances for the Rave / Pub / Food cycle.
  fn_def := pg_get_functiondef('public.book_bokemong_effectiveness_191(text,text)'::regprocedure);
  if position('when p_defender=''Rave'' and p_attacker=''Pub'' then 0.80' in fn_def)=0 then
    fn_def := replace(fn_def,
      'when p_defender=''Regime'' and p_attacker=''Pool'' then 0.80'||E'\n    else 1.00',
      'when p_defender=''Regime'' and p_attacker=''Pool'' then 0.80'||E'\n    when p_defender=''Rave'' and p_attacker=''Pub'' then 0.80'||E'\n    when p_defender=''Pub'' and p_attacker=''Food'' then 0.80'||E'\n    when p_defender=''Food'' and p_attacker=''Rave'' then 0.80'||E'\n    else 1.00');
    execute fn_def;
  end if;
end
$migration$;

create or replace function public.book_version()
returns integer
language sql
set search_path = public, extensions
as $function$
  select 39
$function$;

commit;

-- Verification: expect v39 and all three new server-side behaviours.
select
  public.book_version() as database_function_version,
  position('captains' in pg_get_functiondef('public.book_player_action(text,text,jsonb)'::regprocedure))>0 as fantasy_captains_installed,
  position('bokemongTeam' in pg_get_functiondef('public.book_bokemong_action(text,text,jsonb)'::regprocedure))>0 as bokemong_team_change_installed,
  position('book_bokemong_reward_193' in pg_get_functiondef('public.book_bokemong_action(text,text,jsonb)'::regprocedure))>0 as bokemong_rewards_installed,
  (select data ? 'fantasyWeeks' and data ? 'bokemongs' from public.book where id=1) as expected_collections_ready;
