-- Book1 1.9.1 — turn-based Bokémong battles
-- Database function version: 36

begin;

create or replace function public.book_bokemong_type_191(p_id text)
returns text
language sql
immutable
set search_path = public, extensions
as $function$
  select case p_id
    when 'clanker' then 'Machine'
    when 'finance-wyrm' then 'Finance'
    when 'prestige-pigeon' then 'Regime'
    when 'cue-goblin' then 'Pool'
    when 'desk-rat' then 'Office'
    when 'rack-beast' then 'Pool'
    when 'pocket-wyrm' then 'Pool'
    when 'table-tyrant' then 'Regime'
    when 'arcade-gremlin' then 'Arcade'
    when 'grid-fiend' then 'Arcade'
    when 'bishop-bastard' then 'Strategy'
    when 'grind-goblin' then 'Office'
    when 'spreadsheet-necromancer' then 'Office'
    when 'hr-parasite' then 'Office'
    when 'connectivore' then 'Arcade'
    when 'mong' then 'Abomination'
    when 'pub-lich' then 'Pub'
    when 'rave-mite' then 'Rave'
    when 'kitchen-ogre' then 'Food'
    when 'regime-hound' then 'Regime'
    else 'Machine'
  end
$function$;

create or replace function public.book_bokemong_move_name_191(p_id text, p_move integer)
returns text
language plpgsql
immutable
set search_path = public, extensions
as $function$
declare t text := public.book_bokemong_type_191(p_id);
begin
  return case t
    when 'Machine' then (array['Servo Smack','Overclock','Firewall','Critical Error'])[p_move]
    when 'Finance' then (array['Invoice Bite','Compound Interest','Hedge Position','Audit Bomb'])[p_move]
    when 'Regime' then (array['Decree Slap','Red Stamp','Party Line','Purge'])[p_move]
    when 'Pool' then (array['Chalk Jab','Bank Shot','Safety Play','Golden Break'])[p_move]
    when 'Office' then (array['Teams Ping','Reply All','Out of Office','Performance Review'])[p_move]
    when 'Arcade' then (array['Button Mash','Combo Chain','Pause Buffer','Final Boss'])[p_move]
    when 'Strategy' then (array['Pawn Prod','Fork','Castle Up','Mate Threat'])[p_move]
    when 'Abomination' then (array['Wet Slap','Mong Energy','Feral Guard','Absolute State'])[p_move]
    when 'Pub' then (array['Barstool Bash','Last Orders','Round In','Closing Time'])[p_move]
    when 'Rave' then (array['Bass Kick','Strobe Lock','Hydrate','The Drop'])[p_move]
    when 'Food' then (array['Pan Slap','Seasoning','Mise en Place','SERVICE!'])[p_move]
    else (array['Jab','Type Hit','Guard','Big Hit'])[p_move]
  end;
end
$function$;

create or replace function public.book_bokemong_effectiveness_191(p_attacker text, p_defender text)
returns numeric
language sql
immutable
set search_path = public, extensions
as $function$
  select case
    when p_attacker='Pool' and p_defender='Office' then 1.25
    when p_attacker='Office' and p_defender='Finance' then 1.25
    when p_attacker='Finance' and p_defender='Regime' then 1.25
    when p_attacker='Regime' and p_defender='Pool' then 1.25
    when p_attacker='Arcade' and p_defender='Strategy' then 1.25
    when p_attacker='Strategy' and p_defender='Arcade' then 1.25
    when p_attacker='Rave' and p_defender='Pub' then 1.25
    when p_attacker='Pub' and p_defender='Food' then 1.25
    when p_attacker='Food' and p_defender='Rave' then 1.25
    when p_defender='Pool' and p_attacker='Office' then 0.80
    when p_defender='Office' and p_attacker='Finance' then 0.80
    when p_defender='Finance' and p_attacker='Regime' then 0.80
    when p_defender='Regime' and p_attacker='Pool' then 0.80
    else 1.00
  end
$function$;

create or replace function public.book_bokemong_action(p_name text, p_pin text, p_action jsonb)
returns integer
language plpgsql
security definer
set search_path = public, extensions
as $function$
declare
  d jsonb;
  v integer;
  t text := p_action->>'t';
  now_ms bigint := (extract(epoch from now())*1000)::bigint;
  g jsonb;
  bp jsonb;
  opp_bp jsonb;
  idx bigint;
  bid text;
  opponent text;
  role_name text;
  side text;
  other_side text;
  active_key text;
  other_active_key text;
  active_idx integer;
  other_idx integer;
  mon jsonb;
  foe jsonb;
  move_no integer;
  move_name text;
  acc integer;
  move_power integer;
  attacker_power integer;
  attacker_level integer;
  eff numeric;
  roll numeric;
  crit boolean;
  damage integer;
  shield integer;
  hp_after integer;
  next_idx integer;
  battle_winner text;
  team_a jsonb;
  team_b jsonb;
  level_a integer;
  level_b integer;
begin
  role_name:=public.book_check(p_name,p_pin);
  if role_name is null then raise exception 'Wrong name or PIN'; end if;

  select data,version into d,v from public.book where id=1 for update;
  d:=jsonb_set(d,'{bokemongs}',coalesce(d->'bokemongs',jsonb_build_object('players','{}'::jsonb,'battles','[]'::jsonb)),true);
  d:=jsonb_set(d,'{bokemongs,players}',coalesce(d->'bokemongs'->'players','{}'::jsonb),true);
  d:=jsonb_set(d,'{bokemongs,battles}',coalesce(d->'bokemongs'->'battles','[]'::jsonb),true);

  if t='bokemongChallenge' then
    opponent:=p_action->>'opponent';
    if opponent is null or opponent='' or opponent=p_name then raise exception 'Pick another player'; end if;
    bp:=d->'bokemongs'->'players'->p_name;
    opp_bp:=d->'bokemongs'->'players'->opponent;
    if bp is null or opp_bp is null then raise exception 'Both players need Bokémongs'; end if;
    if exists(
      select 1 from jsonb_array_elements(d->'bokemongs'->'battles') x
      where x->>'status' in ('pending','playing')
        and (x->>'a' in (p_name,opponent) or x->>'b' in (p_name,opponent))
    ) then raise exception 'One of you already has an open Bokémong battle'; end if;
    bid:='bt'||now_ms::text||floor(random()*10000)::int::text;
    g:=jsonb_build_object(
      'id',bid,'a',p_name,'b',opponent,'status','pending',
      'createdAt',now_ms,'log',jsonb_build_array(p_name||' challenged '||opponent||' to a 3v3.')
    );
    d:=jsonb_set(d,'{bokemongs,battles}',d->'bokemongs'->'battles'||jsonb_build_array(g),true);

  elsif t in ('bokemongAccept','bokemongDecline','bokemongMove','bokemongForfeit') then
    select ord-1,value into idx,g
    from jsonb_array_elements(d->'bokemongs'->'battles') with ordinality e(value,ord)
    where value->>'id'=p_action->>'id'
    limit 1;
    if g is null then raise exception 'Battle not found'; end if;

    if t='bokemongAccept' then
      if g->>'status'<>'pending' then raise exception 'That challenge is no longer pending'; end if;
      if g->>'b'<>p_name then raise exception 'Only the challenged player can accept'; end if;
      bp:=d->'bokemongs'->'players'->(g->>'a');
      opp_bp:=d->'bokemongs'->'players'->(g->>'b');
      if jsonb_array_length(coalesce(bp->'team','[]'::jsonb))<3 or jsonb_array_length(coalesce(opp_bp->'team','[]'::jsonb))<3 then
        raise exception 'Both players need a full three-mong team';
      end if;
      level_a:=least(50,1+floor(sqrt(greatest(0,public.book_player_xp(d,g->>'a'))/400.0))::int);
      level_b:=least(50,1+floor(sqrt(greatest(0,public.book_player_xp(d,g->>'b'))/400.0))::int);

      select jsonb_agg(jsonb_build_object(
        'id',q.id,
        'hp',70+public.book_bokemong_power_190(q.id)+level_a,
        'maxHp',70+public.book_bokemong_power_190(q.id)+level_a
      ) order by q.ord)
      into team_a
      from (
        select value as id, ord
        from jsonb_array_elements_text(bp->'team') with ordinality x(value,ord)
        order by ord limit 3
      ) q;

      select jsonb_agg(jsonb_build_object(
        'id',q.id,
        'hp',70+public.book_bokemong_power_190(q.id)+level_b,
        'maxHp',70+public.book_bokemong_power_190(q.id)+level_b
      ) order by q.ord)
      into team_b
      from (
        select value as id, ord
        from jsonb_array_elements_text(opp_bp->'team') with ordinality x(value,ord)
        order by ord limit 3
      ) q;

      g:=g||jsonb_build_object(
        'status','playing','teams',jsonb_build_object('a',team_a,'b',team_b),
        'activeA',0,'activeB',0,'guardA',0,'guardB',0,
        'levelA',level_a,'levelB',level_b,
        'turn',case when random()<0.5 then g->>'a' else g->>'b' end,
        'startedAt',now_ms
      );
      g:=jsonb_set(g,'{log}',coalesce(g->'log','[]'::jsonb)||jsonb_build_array(
        (g->>'b')||' accepted. '||(g->>'turn')||' moves first.'
      ),true);

    elsif t='bokemongDecline' then
      if g->>'status'<>'pending' then raise exception 'That challenge is no longer pending'; end if;
      if g->>'b'<>p_name then raise exception 'Only the challenged player can decline'; end if;
      g:=g||jsonb_build_object('status','declined','completedAt',now_ms);
      g:=jsonb_set(g,'{log}',coalesce(g->'log','[]'::jsonb)||jsonb_build_array(p_name||' declined the battle.'),true);

    elsif t='bokemongForfeit' then
      if g->>'status'<>'playing' then raise exception 'That battle is not active'; end if;
      if p_name<>g->>'a' and p_name<>g->>'b' then raise exception 'That is not your battle'; end if;
      battle_winner:=case when p_name=g->>'a' then g->>'b' else g->>'a' end;
      g:=g||jsonb_build_object('status','done','winner',battle_winner,'turn',null,'completedAt',now_ms,'resultReason','forfeit');
      g:=jsonb_set(g,'{log}',coalesce(g->'log','[]'::jsonb)||jsonb_build_array(p_name||' forfeited. '||battle_winner||' wins.'),true);
      bp:=d->'bokemongs'->'players'->battle_winner;
      bp:=jsonb_set(bp,'{wins}',to_jsonb(coalesce((bp->>'wins')::int,0)+1),true);
      d:=jsonb_set(d,array['bokemongs','players',battle_winner],bp,true);
      bp:=d->'bokemongs'->'players'->p_name;
      bp:=jsonb_set(bp,'{losses}',to_jsonb(coalesce((bp->>'losses')::int,0)+1),true);
      d:=jsonb_set(d,array['bokemongs','players',p_name],bp,true);

    else
      if g->>'status'<>'playing' then raise exception 'That battle is not active'; end if;
      if p_name<>g->>'a' and p_name<>g->>'b' then raise exception 'That is not your battle'; end if;
      if g->>'turn'<>p_name then raise exception 'Wait for your turn'; end if;
      move_no:=coalesce((p_action->>'move')::int,0);
      if move_no<1 or move_no>4 then raise exception 'Choose one of the four moves'; end if;

      side:=case when p_name=g->>'a' then 'a' else 'b' end;
      other_side:=case when side='a' then 'b' else 'a' end;
      active_key:=case when side='a' then 'activeA' else 'activeB' end;
      other_active_key:=case when side='a' then 'activeB' else 'activeA' end;
      active_idx:=coalesce((g->>active_key)::int,0);
      other_idx:=coalesce((g->>other_active_key)::int,0);
      mon:=g#>array['teams',side,active_idx::text];
      foe:=g#>array['teams',other_side,other_idx::text];
      if mon is null or coalesce((mon->>'hp')::int,0)<=0 then raise exception 'Your active Bokémong has fainted'; end if;
      if foe is null or coalesce((foe->>'hp')::int,0)<=0 then raise exception 'Their active Bokémong has already fainted'; end if;

      move_name:=public.book_bokemong_move_name_191(mon->>'id',move_no);

      if move_no=3 then
        if side='a' then g:=jsonb_set(g,'{guardA}','12'::jsonb,true);
        else g:=jsonb_set(g,'{guardB}','12'::jsonb,true); end if;
        g:=jsonb_set(g,'{log}',coalesce(g->'log','[]'::jsonb)||jsonb_build_array(
          p_name||'''s '||(mon->>'id')||' used '||move_name||' and braced for the next hit.'
        ),true);
      else
        acc:=case move_no when 1 then 100 when 2 then 92 else 72 end;
        move_power:=case move_no when 1 then 18 when 2 then 26 else 38 end;
        if floor(random()*100)+1>acc then
          g:=jsonb_set(g,'{log}',coalesce(g->'log','[]'::jsonb)||jsonb_build_array(
            p_name||'''s '||(mon->>'id')||' used '||move_name||' — it missed.'
          ),true);
        else
          attacker_power:=public.book_bokemong_power_190(mon->>'id');
          attacker_level:=case when side='a' then coalesce((g->>'levelA')::int,1) else coalesce((g->>'levelB')::int,1) end;
          eff:=case when move_no in (2,4) then public.book_bokemong_effectiveness_191(
            public.book_bokemong_type_191(mon->>'id'),public.book_bokemong_type_191(foe->>'id')
          ) else 1.0 end;
          crit:=random()<0.10;
          roll:=0.85+random()*0.16;
          damage:=greatest(1,floor((move_power+attacker_power/10.0+attacker_level/3.0)*eff*roll*(case when crit then 1.5 else 1 end))::int);
          shield:=case when other_side='a' then coalesce((g->>'guardA')::int,0) else coalesce((g->>'guardB')::int,0) end;
          damage:=greatest(1,damage-shield);
          if other_side='a' then g:=jsonb_set(g,'{guardA}','0'::jsonb,true);
          else g:=jsonb_set(g,'{guardB}','0'::jsonb,true); end if;
          hp_after:=greatest(0,coalesce((foe->>'hp')::int,0)-damage);
          g:=jsonb_set(g,array['teams',other_side,other_idx::text,'hp'],to_jsonb(hp_after),true);
          g:=jsonb_set(g,'{log}',coalesce(g->'log','[]'::jsonb)||jsonb_build_array(
            p_name||'''s '||(mon->>'id')||' used '||move_name||' for '||damage||' damage'||
            case when crit then ' — CRITICAL' else '' end||
            case when eff>1 then ' — super effective' when eff<1 then ' — resisted' else '' end||'.'
          ),true);

          if hp_after<=0 then
            next_idx:=other_idx+1;
            g:=jsonb_set(g,'{log}',coalesce(g->'log','[]'::jsonb)||jsonb_build_array((foe->>'id')||' fainted.'),true);
            if next_idx>=jsonb_array_length(g#>array['teams',other_side]) then
              battle_winner:=p_name;
              g:=g||jsonb_build_object('status','done','winner',battle_winner,'turn',null,'completedAt',now_ms,'resultReason','all fainted');
              g:=jsonb_set(g,'{log}',coalesce(g->'log','[]'::jsonb)||jsonb_build_array(battle_winner||' wins the 3v3.'),true);
              bp:=d->'bokemongs'->'players'->battle_winner;
              bp:=jsonb_set(bp,'{wins}',to_jsonb(coalesce((bp->>'wins')::int,0)+1),true);
              d:=jsonb_set(d,array['bokemongs','players',battle_winner],bp,true);
              opponent:=case when battle_winner=g->>'a' then g->>'b' else g->>'a' end;
              bp:=d->'bokemongs'->'players'->opponent;
              bp:=jsonb_set(bp,'{losses}',to_jsonb(coalesce((bp->>'losses')::int,0)+1),true);
              d:=jsonb_set(d,array['bokemongs','players',opponent],bp,true);
            else
              g:=jsonb_set(g,array[other_active_key],to_jsonb(next_idx),true);
              g:=jsonb_set(g,'{log}',coalesce(g->'log','[]'::jsonb)||jsonb_build_array(
                case when other_side='a' then g->>'a' else g->>'b' end||' sends out '||
                ((g#>array['teams',other_side,next_idx::text])->>'id')||'.'
              ),true);
            end if;
          end if;
        end if;
      end if;

      if g->>'status'='playing' then
        g:=jsonb_set(g,'{turn}',to_jsonb(case when p_name=g->>'a' then g->>'b' else g->>'a' end),true);
      end if;
      g:=jsonb_set(g,'{lastMoveAt}',to_jsonb(now_ms),true);
    end if;

    d:=jsonb_set(d,array['bokemongs','battles',idx::text],g,true);

  else
    raise exception 'Unknown Bokémong action';
  end if;

  d:=jsonb_set(d,'{log}',coalesce(d->'log','[]'::jsonb)||to_jsonb(
    to_char(now() at time zone 'Europe/London','DD Mon HH24:MI')||' '||p_name||' used Bokémong action '||t
  ),true);

  update public.book set data=d,version=v+1,updated_at=now() where id=1;
  return v+1;
end
$function$;

create or replace function public.book_game_detail(p_kind text, p_id text)
returns jsonb
language sql
stable
security invoker
set search_path = public, extensions
as $function$
  select case lower(p_kind)
    when 'connect4' then (
      select g from public.book b,
      lateral jsonb_array_elements(coalesce(b.data->'connect4','[]'::jsonb)) g
      where b.id=1 and g->>'id'=p_id limit 1
    )
    when 'chess' then (
      select g from public.book b,
      lateral jsonb_array_elements(coalesce(b.data->'chess','[]'::jsonb)) g
      where b.id=1 and g->>'id'=p_id limit 1
    )
    when 'battleships' then (
      select g from public.book b,
      lateral jsonb_array_elements(coalesce(b.data->'battleships','[]'::jsonb)) g
      where b.id=1 and g->>'id'=p_id limit 1
    )
    when 'bokemong' then (
      select g from public.book b,
      lateral jsonb_array_elements(coalesce(b.data->'bokemongs'->'battles','[]'::jsonb)) g
      where b.id=1 and g->>'id'=p_id limit 1
    )
    else null
  end
$function$;

create or replace function public.book_client_state()
returns jsonb
language sql
stable
security invoker
set search_path = public, extensions
as $function$
  with base as (
    select b.version,
      jsonb_set(
        jsonb_set(
          jsonb_set(
            jsonb_set(
              b.data,
              '{battleships}',
              coalesce((
                select jsonb_agg(
                  case when g.elem->>'status'='done' then g.elem-'shots'-'sunk'-'ready'-'ships' else g.elem end
                  order by g.ord
                )
                from jsonb_array_elements(coalesce(b.data->'battleships','[]'::jsonb)) with ordinality g(elem,ord)
              ),'[]'::jsonb),true
            ),
            '{connect4}',
            coalesce((
              select jsonb_agg(
                case when g.elem->>'status' in ('done','draw')
                  then (g.elem-'history'-'board')||jsonb_build_object(
                    'moves',(select count(*) from jsonb_array_elements(coalesce(g.elem->'board','[]'::jsonb)) c where c<>'null'::jsonb)
                  )
                  else g.elem end
                order by g.ord
              )
              from jsonb_array_elements(coalesce(b.data->'connect4','[]'::jsonb)) with ordinality g(elem,ord)
            ),'[]'::jsonb),true
          ),
          '{chess}',
          coalesce((
            select jsonb_agg(case when g.elem->>'status' in ('done','draw') then g.elem-'history' else g.elem end order by g.ord)
            from jsonb_array_elements(coalesce(b.data->'chess','[]'::jsonb)) with ordinality g(elem,ord)
          ),'[]'::jsonb),true
        ),
        '{bets}',
        coalesce((
          select jsonb_agg(g.elem order by g.ord)
          from jsonb_array_elements(coalesce(b.data->'bets','[]'::jsonb)) with ordinality g(elem,ord)
          where g.elem->>'status'='open'
        ),'[]'::jsonb),true
      ) as d
    from public.book b where b.id=1
  )
  select jsonb_build_object(
    'data',
    jsonb_set(
      base.d,
      '{bokemongs,battles}',
      coalesce((
        select jsonb_agg(
          case when g.elem->>'status' in ('pending','playing') then g.elem else g.elem-'teams'-'log' end
          order by g.ord
        )
        from jsonb_array_elements(coalesce(base.d->'bokemongs'->'battles','[]'::jsonb)) with ordinality g(elem,ord)
      ),'[]'::jsonb),
      true
    ),
    'version',base.version
  )
  from base
$function$;

create or replace function public.book_version()
returns integer
language sql
set search_path = public, extensions
as $function$
  select 36
$function$;

revoke all on function public.book_bokemong_type_191(text) from public;
revoke all on function public.book_bokemong_move_name_191(text,integer) from public;
revoke all on function public.book_bokemong_effectiveness_191(text,text) from public;
revoke all on function public.book_bokemong_action(text,text,jsonb) from public;
grant execute on function public.book_bokemong_action(text,text,jsonb) to anon, authenticated, service_role;
grant execute on function public.book_game_detail(text,text) to anon, authenticated;

commit;

select public.book_version() as database_function_version,
       public.book_bokemong_move_name_191('clanker',4) as clanker_finisher,
       public.book_bokemong_effectiveness_191('Pool','Office') as pool_vs_office;
