-- Book1 1.9.0 — milestones, social calendar and Bokemongs
-- Database function version: 35
--
-- New player-facing writes use one PIN-validated RPC so the browser never writes
-- the Book row directly. Existing Book1 auth is name/PIN based.

begin;

create or replace function public.book_milestone_progress_190(p_data jsonb, p_player text, p_key text)
returns integer
language plpgsql
stable
set search_path = public, extensions
as $function$
declare
  v integer := 0;
begin
  if p_key='pool250' then
    select count(*)::int into v
    from jsonb_array_elements(coalesce(p_data->'weeks','[]'::jsonb)) w
    cross join lateral jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) g
    where g->>'s1' is not null and (g->>'p1'=p_player or g->>'p2'=p_player);

  elsif p_key='balls1000' then
    select coalesce(sum(
      case when g->>'p1'=p_player then coalesce((g->>'s1')::int,0)
           else coalesce((g->>'s2')::int,0) end
    ),0)::int into v
    from jsonb_array_elements(coalesce(p_data->'weeks','[]'::jsonb)) w
    cross join lateral jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) g
    where g->>'s1' is not null and (g->>'p1'=p_player or g->>'p2'=p_player);

  elsif p_key='wins100' then
    select count(*)::int into v
    from jsonb_array_elements(coalesce(p_data->'weeks','[]'::jsonb)) w
    cross join lateral jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) g
    where g->>'s1' is not null
      and (
        ((g->>'s1')::int>(g->>'s2')::int and g->>'p1'=p_player)
        or ((g->>'s2')::int>(g->>'s1')::int and g->>'p2'=p_player)
      );

  elsif p_key='mini100' then
    select
      (select count(*) from jsonb_array_elements(coalesce(p_data->'connect4','[]'::jsonb)) g
       where g->>'status' in ('done','draw') and (g->>'challenger'=p_player or g->>'opponent'=p_player))
      +(select count(*) from jsonb_array_elements(coalesce(p_data->'chess','[]'::jsonb)) g
       where g->>'status' in ('done','draw') and (g->>'challenger'=p_player or g->>'opponent'=p_player))
      +(select count(*) from jsonb_array_elements(coalesce(p_data->'battleships','[]'::jsonb)) g
       where g->>'status'='done' and (g->>'challenger'=p_player or g->>'opponent'=p_player))
      +(select count(*) from jsonb_array_elements(coalesce(p_data->'hogDuels','[]'::jsonb)) g
       where g->>'status'='done' and (g->>'challenger'=p_player or g->>'opponent'=p_player))
      into v;

  elsif p_key='c4wins50' then
    select count(*)::int into v
    from jsonb_array_elements(coalesce(p_data->'connect4','[]'::jsonb)) g
    where g->>'status'='done' and g->>'winner'=p_player;

  elsif p_key='chesswins25' then
    select count(*)::int into v
    from jsonb_array_elements(coalesce(p_data->'chess','[]'::jsonb)) g
    where g->>'status'='done' and g->>'winner'=p_player;

  elsif p_key='weekly50' then
    select count(*)::int into v
    from jsonb_array_elements(coalesce(p_data->'challengeClaims','[]'::jsonb)) c
    where c->>'player'=p_player;
  end if;
  return coalesce(v,0);
end
$function$;

create or replace function public.book_bokemong_power_190(p_id text)
returns integer
language sql
immutable
set search_path = public, extensions
as $function$
  select case p_id
    when 'clanker' then 62 when 'finance-wyrm' then 64 when 'prestige-pigeon' then 60
    when 'cue-goblin' then 42 when 'desk-rat' then 40
    when 'rack-beast' then 72 when 'pocket-wyrm' then 74 when 'table-tyrant' then 82
    when 'arcade-gremlin' then 70 when 'grid-fiend' then 73 when 'bishop-bastard' then 76
    when 'grind-goblin' then 80 when 'spreadsheet-necromancer' then 84
    when 'hr-parasite' then 69 when 'connectivore' then 71 when 'mong' then 79
    when 'pub-lich' then 68 when 'rave-mite' then 46 when 'kitchen-ogre' then 75
    when 'regime-hound' then 92 else 0 end
$function$;

create or replace function public.book_19_action(p_name text, p_pin text, p_action jsonb)
returns integer
language plpgsql
security definer
set search_path = public, extensions
as $function$
declare
  d jsonb;
  v integer;
  role_name text;
  t text := p_action->>'t';
  now_ms bigint := (extract(epoch from now())*1000)::bigint;
  k text;
  target integer;
  reward integer;
  unlock_id text;
  progress integer;
  cur integer;
  ev jsonb;
  bp jsonb;
  opp_bp jsonb;
  idx bigint;
  eid text;
  slot text;
  starter text;
  own_score integer := 0;
  opp_score integer := 0;
  battle_winner text;
  battle_id text;
begin
  role_name := public.book_check(p_name,p_pin);
  if role_name is null then raise exception 'Wrong name or PIN'; end if;

  select data,version into d,v from public.book where id=1 for update;

  d:=jsonb_set(d,'{milestoneClaims}',coalesce(d->'milestoneClaims','[]'::jsonb),true);
  d:=jsonb_set(d,'{events}',coalesce(d->'events','[]'::jsonb),true);
  d:=jsonb_set(d,'{bokemongs}',coalesce(d->'bokemongs',jsonb_build_object('players','{}'::jsonb,'battles','[]'::jsonb)),true);
  d:=jsonb_set(d,'{bokemongs,players}',coalesce(d->'bokemongs'->'players','{}'::jsonb),true);
  d:=jsonb_set(d,'{bokemongs,battles}',coalesce(d->'bokemongs'->'battles','[]'::jsonb),true);

  if t='milestoneClaim' then
    k:=p_action->>'key';
    target:=case k when 'pool250' then 250 when 'balls1000' then 1000 when 'wins100' then 100
      when 'mini100' then 100 when 'c4wins50' then 50 when 'chesswins25' then 25 when 'weekly50' then 50 else null end;
    reward:=case k when 'pool250' then 25000 when 'balls1000' then 30000 when 'wins100' then 30000
      when 'mini100' then 20000 when 'c4wins50' then 20000 when 'chesswins25' then 20000 when 'weekly50' then 25000 else null end;
    unlock_id:=case k when 'pool250' then 'rack-beast' when 'balls1000' then 'pocket-wyrm' when 'wins100' then 'table-tyrant'
      when 'mini100' then 'arcade-gremlin' when 'c4wins50' then 'grid-fiend' when 'chesswins25' then 'bishop-bastard'
      when 'weekly50' then 'grind-goblin' else null end;
    if target is null then raise exception 'Unknown milestone'; end if;
    if exists(select 1 from jsonb_array_elements(d->'milestoneClaims') x where x->>'player'=p_name and x->>'key'=k) then
      raise exception 'Already claimed';
    end if;
    progress:=public.book_milestone_progress_190(d,p_name,k);
    if progress<target then raise exception 'Milestone not complete (%/%).',progress,target; end if;

    d:=jsonb_set(d,'{chips}',coalesce(d->'chips','{}'::jsonb),true);
    cur:=coalesce((d->'chips'->>p_name)::int,1000);
    d:=jsonb_set(d,array['chips',p_name],to_jsonb(cur+reward),true);
    d:=jsonb_set(d,'{milestoneClaims}',d->'milestoneClaims'||jsonb_build_array(jsonb_build_object(
      'player',p_name,'key',k,'reward',reward,'unlock',unlock_id,'progress',progress,'at',now_ms
    )),true);

    bp:=d->'bokemongs'->'players'->p_name;
    if bp is not null and not exists(
      select 1 from jsonb_array_elements(coalesce(bp->'owned','[]'::jsonb)) x where x->>'id'=unlock_id
    ) then
      bp:=jsonb_set(bp,'{owned}',coalesce(bp->'owned','[]'::jsonb)||jsonb_build_array(jsonb_build_object(
        'id',unlock_id,'acquiredAt',now_ms,'source',k
      )),true);
      d:=jsonb_set(d,array['bokemongs','players',p_name],bp,true);
    end if;

  elsif t='eventCreate' then
    if length(trim(coalesce(p_action->>'title','')))<2 then raise exception 'Event needs a title'; end if;
    if coalesce(p_action->>'mode','fixed')='poll' and jsonb_array_length(coalesce(p_action->'slots','[]'::jsonb))<2 then
      raise exception 'Give a date poll at least two options';
    end if;
    if coalesce(p_action->>'mode','fixed')<>'poll' and coalesce(p_action->>'when','')='' then
      raise exception 'Fixed event needs a date';
    end if;
    eid:='ev'||now_ms::text||floor(random()*10000)::int::text;
    ev:=jsonb_build_object(
      'id',eid,'title',left(trim(p_action->>'title'),80),
      'mode',case when p_action->>'mode'='poll' then 'poll' else 'fixed' end,
      'when',nullif(p_action->>'when',''),
      'slots',coalesce(p_action->'slots','[]'::jsonb),
      'organiser',p_name,'status',case when p_action->>'mode'='poll' then 'planning' else 'confirmed' end,
      'rsvps','{}'::jsonb,'availability','{}'::jsonb,'createdAt',now_ms
    );
    d:=jsonb_set(d,'{events}',d->'events'||jsonb_build_array(ev),true);

  elsif t in ('eventRsvp','eventVote','eventConfirm','eventCancel') then
    select ord-1,value into idx,ev
    from jsonb_array_elements(d->'events') with ordinality e(value,ord)
    where value->>'id'=p_action->>'id'
    limit 1;
    if ev is null then raise exception 'Event not found'; end if;

    if t='eventRsvp' then
      if p_action->>'state' not in ('in','maybe','out') then raise exception 'Bad RSVP'; end if;
      ev:=jsonb_set(ev,'{rsvps}',coalesce(ev->'rsvps','{}'::jsonb),true);
      ev:=jsonb_set(ev,array['rsvps',p_name],to_jsonb(p_action->>'state'),true);

    elsif t='eventVote' then
      slot:=p_action->>'slot';
      if p_action->>'state' not in ('free','maybe','unavailable') then raise exception 'Bad availability state'; end if;
      if not exists(select 1 from jsonb_array_elements_text(coalesce(ev->'slots','[]'::jsonb)) x where x=slot) then raise exception 'Event slot not found'; end if;
      ev:=jsonb_set(ev,'{availability}',coalesce(ev->'availability','{}'::jsonb),true);
      if ev->'availability'->p_name is null then ev:=jsonb_set(ev,array['availability',p_name],'{}'::jsonb,true); end if;
      ev:=jsonb_set(ev,array['availability',p_name,slot],to_jsonb(p_action->>'state'),true);

    elsif t='eventConfirm' then
      if ev->>'organiser'<>p_name and role_name<>'admin' then raise exception 'Only the organiser or regime can confirm'; end if;
      slot:=p_action->>'slot';
      if not exists(select 1 from jsonb_array_elements_text(coalesce(ev->'slots','[]'::jsonb)) x where x=slot) then raise exception 'Event slot not found'; end if;
      ev:=ev||jsonb_build_object('confirmedAt',slot,'status','confirmed');

    else
      if ev->>'organiser'<>p_name and role_name<>'admin' then raise exception 'Only the organiser or regime can cancel'; end if;
      ev:=ev||jsonb_build_object('status','cancelled');
    end if;
    d:=jsonb_set(d,array['events',idx::text],ev,true);

  elsif t='bokemongStarter' then
    starter:=p_action->>'starter';
    if starter not in ('clanker','finance-wyrm','prestige-pigeon') then raise exception 'Bad starter'; end if;
    if d->'bokemongs'->'players'->p_name is not null then raise exception 'Starter already chosen'; end if;
    bp:=jsonb_build_object(
      'starter',starter,
      'owned',jsonb_build_array(
        jsonb_build_object('id',starter,'acquiredAt',now_ms,'source','starter'),
        jsonb_build_object('id','cue-goblin','acquiredAt',now_ms,'source','starter-pack'),
        jsonb_build_object('id','desk-rat','acquiredAt',now_ms,'source','starter-pack')
      ),
      'team',jsonb_build_array(starter,'cue-goblin','desk-rat'),
      'wins',0,'losses',0
    );
    d:=jsonb_set(d,array['bokemongs','players',p_name],bp,true);

  elsif t='bokemongBattle' then
    if p_action->>'opponent'=p_name then raise exception 'You cannot battle yourself'; end if;
    bp:=d->'bokemongs'->'players'->p_name;
    opp_bp:=d->'bokemongs'->'players'->(p_action->>'opponent');
    if bp is null or opp_bp is null then raise exception 'Both players need Bokemongs'; end if;
    if jsonb_array_length(coalesce(bp->'team','[]'::jsonb))<3 or jsonb_array_length(coalesce(opp_bp->'team','[]'::jsonb))<3 then
      raise exception 'Both players need a full three-mong team';
    end if;

    select coalesce(sum(public.book_bokemong_power_190(x)),0)::int into own_score
    from jsonb_array_elements_text(bp->'team') x;
    select coalesce(sum(public.book_bokemong_power_190(x)),0)::int into opp_score
    from jsonb_array_elements_text(opp_bp->'team') x;

    own_score:=own_score + least(100,floor(sqrt(greatest(0,public.book_player_xp(d,p_name))/400.0))::int*2) + floor(random()*21)::int;
    opp_score:=opp_score + least(100,floor(sqrt(greatest(0,public.book_player_xp(d,p_action->>'opponent'))/400.0))::int*2) + floor(random()*21)::int;
    if own_score=opp_score then own_score:=own_score+floor(random()*2)::int; end if;
    battle_winner:=case when own_score>opp_score then p_name else p_action->>'opponent' end;

    bp:=jsonb_set(bp,array[case when battle_winner=p_name then 'wins' else 'losses' end],
      to_jsonb(coalesce((bp->>case when battle_winner=p_name then 'wins' else 'losses' end)::int,0)+1),true);
    opp_bp:=jsonb_set(opp_bp,array[case when battle_winner=p_name then 'losses' else 'wins' end],
      to_jsonb(coalesce((opp_bp->>case when battle_winner=p_name then 'losses' else 'wins' end)::int,0)+1),true);
    d:=jsonb_set(d,array['bokemongs','players',p_name],bp,true);
    d:=jsonb_set(d,array['bokemongs','players',p_action->>'opponent'],opp_bp,true);

    battle_id:='bb'||now_ms::text||floor(random()*10000)::int::text;
    d:=jsonb_set(d,'{bokemongs,battles}',d->'bokemongs'->'battles'||jsonb_build_array(jsonb_build_object(
      'id',battle_id,'a',p_name,'b',p_action->>'opponent','scoreA',own_score,'scoreB',opp_score,
      'winner',battle_winner,'at',now_ms
    )),true);

  else
    raise exception 'Unknown Book1.9 action';
  end if;

  d:=jsonb_set(d,'{log}',coalesce(d->'log','[]'::jsonb)||to_jsonb(
    to_char(now() at time zone 'Europe/London','DD Mon HH24:MI')||' '||p_name||' used 1.9 action '||t
  ),true);

  update public.book set data=d,version=v+1,updated_at=now() where id=1;
  return v+1;
end
$function$;

update public.book
set data = jsonb_set(
  jsonb_set(
    jsonb_set(
      data,
      '{milestoneClaims}',coalesce(data->'milestoneClaims','[]'::jsonb),true
    ),
    '{events}',coalesce(data->'events','[]'::jsonb),true
  ),
  '{bokemongs}',coalesce(data->'bokemongs',jsonb_build_object('players','{}'::jsonb,'battles','[]'::jsonb)),true
), updated_at=now()
where id=1;

create or replace function public.book_version()
returns integer
language sql
set search_path = public, extensions
as $function$
  select 35
$function$;

revoke all on function public.book_milestone_progress_190(jsonb,text,text) from public;
revoke all on function public.book_bokemong_power_190(text) from public;
revoke all on function public.book_19_action(text,text,jsonb) from public;
grant execute on function public.book_19_action(text,text,jsonb) to anon, authenticated, service_role;
grant execute on function public.book_milestone_progress_190(jsonb,text,text) to service_role;
grant execute on function public.book_bokemong_power_190(text) to service_role;

commit;

-- Verification
select
  public.book_version() as database_function_version,
  (select data ? 'milestoneClaims' and data ? 'events' and data ? 'bokemongs' from public.book where id=1) as collections_ready,
  public.book_milestone_progress_190((select data from public.book where id=1),'Chef','pool250') as chef_pool_games;
