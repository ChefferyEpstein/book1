-- Book1 1.8.0 database update (v27)
-- Connect 4: player challenges, chip escrow, server-authoritative turns,
-- win/draw settlement and forfeits.
-- Safe to re-run.

begin;

create or replace function public.book_c4_winner(p_board jsonb, p_player text)
returns boolean
language plpgsql
immutable
as $function$
declare
  r int;
  c int;
begin
  if p_player is null or jsonb_typeof(p_board) <> 'array' or jsonb_array_length(p_board) <> 42 then
    return false;
  end if;

  for r in 0..5 loop
    for c in 0..6 loop
      if p_board->>(r*7+c) <> p_player then
        continue;
      end if;

      if c <= 3
        and p_board->>(r*7+c+1) = p_player
        and p_board->>(r*7+c+2) = p_player
        and p_board->>(r*7+c+3) = p_player then
        return true;
      end if;

      if r <= 2
        and p_board->>((r+1)*7+c) = p_player
        and p_board->>((r+2)*7+c) = p_player
        and p_board->>((r+3)*7+c) = p_player then
        return true;
      end if;

      if r <= 2 and c <= 3
        and p_board->>((r+1)*7+c+1) = p_player
        and p_board->>((r+2)*7+c+2) = p_player
        and p_board->>((r+3)*7+c+3) = p_player then
        return true;
      end if;

      if r <= 2 and c >= 3
        and p_board->>((r+1)*7+c-1) = p_player
        and p_board->>((r+2)*7+c-2) = p_player
        and p_board->>((r+3)*7+c-3) = p_player then
        return true;
      end if;
    end loop;
  end loop;

  return false;
end
$function$;

do $$
declare
  f text;
  anchor text := '  elsif t = ''bsCreate'' then';
  c4 text := $c4$
  elsif t = 'c4Create' then
    if p_action->>'opponent' is null or p_action->>'opponent' = p_name then raise exception 'Pick someone else to challenge.'; end if;
    if not exists (
      select 1
      from jsonb_array_elements(coalesce(d->'players','[]'::jsonb)) p
      where p->>'name' = p_action->>'opponent'
        and coalesce((p->>'active')::boolean, false)
    ) then raise exception 'That player is not active.'; end if;
    s1 := coalesce((p_action->>'stake')::int, 0);
    if s1 < 0 then raise exception 'Bad stake.'; end if;
    wi := coalesce((d->'chips'->>p_name)::int, 1000);
    if s1 > wi then raise exception 'You cannot stake more than your chip balance.'; end if;

    d := d || jsonb_build_object('connect4', coalesce(d->'connect4','[]'::jsonb), 'chips', coalesce(d->'chips','{}'::jsonb));
    if exists (
      select 1 from jsonb_array_elements(d->'connect4') x
      where x->>'status' in ('pending','playing')
        and (
          ((x->>'challenger') = p_name and (x->>'opponent') = (p_action->>'opponent'))
          or
          ((x->>'opponent') = p_name and (x->>'challenger') = (p_action->>'opponent'))
        )
    ) then raise exception 'You already have a Connect 4 game with them.'; end if;

    if s1 > 0 then
      d := jsonb_set(d, array['chips', p_name], to_jsonb(wi - s1));
    end if;

    bid := 'c4' || ((extract(epoch from clock_timestamp())*1000)::bigint)::text;
    d := jsonb_set(d, '{connect4}', (d->'connect4') || jsonb_build_array(jsonb_build_object(
      'id', bid,
      'challenger', p_name,
      'opponent', p_action->>'opponent',
      'stake', s1,
      'status', 'pending',
      'turn', null,
      'winner', null,
      'board', '[
        null,null,null,null,null,null,null,
        null,null,null,null,null,null,null,
        null,null,null,null,null,null,null,
        null,null,null,null,null,null,null,
        null,null,null,null,null,null,null,
        null,null,null,null,null,null,null
      ]'::jsonb,
      'createdAt', (extract(epoch from now())*1000)::bigint
    )));
    d := jsonb_set(d, '{log}', (d->'log') || to_jsonb(format('%s challenged %s to Connect 4%s', p_name, p_action->>'opponent', case when s1>0 then format(' for %s chips',s1) else '' end)));

  elsif t = 'c4Accept' then
    i := null;
    for j in 0 .. coalesce(jsonb_array_length(d->'connect4'),0)-1 loop
      if d->'connect4'->j->>'id' = p_action->>'id' then i := j; end if;
    end loop;
    if i is null then raise exception 'That challenge is gone.'; end if;
    g := d->'connect4'->i;
    if g->>'status' <> 'pending' then raise exception 'That challenge is already settled.'; end if;
    if g->>'opponent' <> p_name then raise exception 'That challenge is not for you.'; end if;

    s1 := coalesce((g->>'stake')::int,0);
    wi := coalesce((d->'chips'->>p_name)::int,1000);
    if s1 > wi then raise exception 'You cannot stake more than your chip balance.'; end if;
    if s1 > 0 then d := jsonb_set(d,array['chips',p_name],to_jsonb(wi-s1)); end if;

    opp := case when random() < 0.5 then g->>'challenger' else g->>'opponent' end;
    g := g || jsonb_build_object(
      'status','playing',
      'turn',opp,
      'startedAt',(extract(epoch from now())*1000)::bigint
    );
    d := jsonb_set(d,array['connect4',i::text],g);
    d := jsonb_set(d,'{log}',(d->'log') || to_jsonb(format('%s and %s started Connect 4; %s goes first',g->>'challenger',g->>'opponent',opp)));

  elsif t in ('c4Decline','c4Cancel') then
    i := null;
    for j in 0 .. coalesce(jsonb_array_length(d->'connect4'),0)-1 loop
      if d->'connect4'->j->>'id' = p_action->>'id' then i := j; end if;
    end loop;
    if i is null then raise exception 'That challenge is gone.'; end if;
    g := d->'connect4'->i;
    if g->>'status' <> 'pending' then raise exception 'That challenge has already started or finished.'; end if;
    if t = 'c4Decline' and g->>'opponent' <> p_name then raise exception 'That challenge is not for you.'; end if;
    if t = 'c4Cancel' and g->>'challenger' <> p_name then raise exception 'That is not your challenge.'; end if;

    s1 := coalesce((g->>'stake')::int,0);
    if s1 > 0 then
      wi := coalesce((d->'chips'->>(g->>'challenger'))::int,1000);
      d := jsonb_set(d,array['chips',g->>'challenger'],to_jsonb(wi+s1));
    end if;
    g := g || jsonb_build_object('status',case when t='c4Decline' then 'declined' else 'cancelled' end);
    d := jsonb_set(d,array['connect4',i::text],g);
    d := jsonb_set(d,'{log}',(d->'log') || to_jsonb(format('%s %s a Connect 4 challenge',p_name,case when t='c4Decline' then 'declined' else 'cancelled' end)));

  elsif t = 'c4Drop' then
    i := null;
    for j in 0 .. coalesce(jsonb_array_length(d->'connect4'),0)-1 loop
      if d->'connect4'->j->>'id' = p_action->>'id' then i := j; end if;
    end loop;
    if i is null then raise exception 'That game is gone.'; end if;
    g := d->'connect4'->i;
    if g->>'status' <> 'playing' then raise exception 'That game is not in progress.'; end if;
    if g->>'turn' <> p_name then raise exception 'It is not your turn.'; end if;
    if p_name <> (g->>'challenger') and p_name <> (g->>'opponent') then raise exception 'That is not your game.'; end if;

    s1 := (p_action->>'col')::int;
    if s1 is null or s1 < 0 or s1 > 6 then raise exception 'Bad column.'; end if;
    w := g->'board';
    if jsonb_typeof(w) <> 'array' or jsonb_array_length(w) <> 42 then raise exception 'Bad Connect 4 board.'; end if;

    s2 := null;
    for j in reverse 5..0 loop
      if w->>(j*7+s1) is null then
        s2 := j;
        exit;
      end if;
    end loop;
    if s2 is null then raise exception 'That column is full.'; end if;

    w := jsonb_set(w,array[(s2*7+s1)::text],to_jsonb(p_name),false);
    g := jsonb_set(g,'{board}',w);

    if public.book_c4_winner(w,p_name) then
      g := g || jsonb_build_object('status','done','winner',p_name,'turn',null,'doneAt',(extract(epoch from now())*1000)::bigint);
      s1 := coalesce((g->>'stake')::int,0);
      if s1 > 0 then
        wi := coalesce((d->'chips'->>p_name)::int,1000);
        d := jsonb_set(d,array['chips',p_name],to_jsonb(wi+s1*2));
      end if;
      d := jsonb_set(d,'{log}',(d->'log') || to_jsonb(format('%s won Connect 4 against %s%s',p_name,case when p_name=g->>'challenger' then g->>'opponent' else g->>'challenger' end,case when s1>0 then format(' and took %s chips',s1*2) else '' end)));
    elsif not exists (select 1 from jsonb_array_elements(w) e where e = 'null'::jsonb) then
      g := g || jsonb_build_object('status','draw','winner',null,'turn',null,'doneAt',(extract(epoch from now())*1000)::bigint);
      s1 := coalesce((g->>'stake')::int,0);
      if s1 > 0 then
        wi := coalesce((d->'chips'->>(g->>'challenger'))::int,1000);
        d := jsonb_set(d,array['chips',g->>'challenger'],to_jsonb(wi+s1));
        wi := coalesce((d->'chips'->>(g->>'opponent'))::int,1000);
        d := jsonb_set(d,array['chips',g->>'opponent'],to_jsonb(wi+s1));
      end if;
      d := jsonb_set(d,'{log}',(d->'log') || to_jsonb(format('%s and %s drew at Connect 4; stakes returned',g->>'challenger',g->>'opponent')));
    else
      opp := case when p_name=g->>'challenger' then g->>'opponent' else g->>'challenger' end;
      g := jsonb_set(g,'{turn}',to_jsonb(opp));
    end if;
    d := jsonb_set(d,array['connect4',i::text],g);

  elsif t = 'c4Forfeit' then
    i := null;
    for j in 0 .. coalesce(jsonb_array_length(d->'connect4'),0)-1 loop
      if d->'connect4'->j->>'id' = p_action->>'id' then i := j; end if;
    end loop;
    if i is null then raise exception 'That game is gone.'; end if;
    g := d->'connect4'->i;
    if g->>'status' <> 'playing' then raise exception 'That game is not in progress.'; end if;
    if p_name <> g->>'challenger' and p_name <> g->>'opponent' then raise exception 'That is not your game.'; end if;

    opp := case when p_name=g->>'challenger' then g->>'opponent' else g->>'challenger' end;
    g := g || jsonb_build_object('status','done','winner',opp,'turn',null,'doneAt',(extract(epoch from now())*1000)::bigint);
    s1 := coalesce((g->>'stake')::int,0);
    if s1 > 0 then
      wi := coalesce((d->'chips'->>opp)::int,1000);
      d := jsonb_set(d,array['chips',opp],to_jsonb(wi+s1*2));
    end if;
    d := jsonb_set(d,array['connect4',i::text],g);
    d := jsonb_set(d,'{log}',(d->'log') || to_jsonb(format('%s forfeited Connect 4 to %s',p_name,opp)));
$c4$;
begin
  select pg_get_functiondef(
    'public.book_player_action(text,text,jsonb)'::regprocedure
  ) into f;

  if position('elsif t = ''c4Create'' then' in f) > 0 then
    null;
  elsif position(anchor in f) > 0 then
    f := replace(f, anchor, c4 || E'\n' || anchor);
    execute f;
  else
    raise exception 'Book1 1.8.0 migration stopped: expected Battleships anchor was not found. No changes committed.';
  end if;
end
$$;

-- Ensure existing live books have the collection even before the first challenge.
update public.book
set
  data = jsonb_set(data,'{connect4}','[]'::jsonb,true),
  version = version + 1,
  updated_at = now()
where id = 1
  and not (data ? 'connect4');

create or replace function public.book_version()
returns integer
language sql
as $function$
  select 27
$function$;

commit;

-- Verification: should show 27 / true / true.
select
  public.book_version() as database_function_version,
  position(
    'elsif t = ''c4Create'' then' in
    pg_get_functiondef('public.book_player_action(text,text,jsonb)'::regprocedure)
  ) > 0 as connect4_actions_installed,
  public.book_c4_winner(
    '[ "Chef","Chef","Chef","Chef",null,null,null,
       null,null,null,null,null,null,null,
       null,null,null,null,null,null,null,
       null,null,null,null,null,null,null,
       null,null,null,null,null,null,null,
       null,null,null,null,null,null,null ]'::jsonb,
    'Chef'
  ) as connect4_win_check;
