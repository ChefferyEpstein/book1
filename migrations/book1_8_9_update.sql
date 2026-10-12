-- Book1 1.8.9 — Chess & Rivalries + scalable progression
-- Database function version: 31

create or replace function public.book_prestige_xp_required()
returns integer
language sql
immutable
as $function$
  select 20000
$function$;

create or replace function public.book_wheel_cooldown_minutes(p_data jsonb, p_name text)
returns integer
language sql
immutable
as $function$
  select case
    when coalesce((p_data->'progression'->p_name->>'prestige')::int,0) >= 10 then 5
    when coalesce((p_data->'progression'->p_name->>'prestige')::int,0) >= 5 then 10
    when coalesce((p_data->'progression'->p_name->>'prestige')::int,0) >= 3 then 15
    when coalesce((p_data->'progression'->p_name->>'prestige')::int,0) >= 2 then 20
    when coalesce((p_data->'progression'->p_name->>'prestige')::int,0) >= 1 then 25
    else 30
  end
$function$;

create or replace function public.book_chess_initial_board()
returns jsonb
language sql
immutable
as $function$
  select '[
    "bR","bN","bB","bQ","bK","bB","bN","bR",
    "bP","bP","bP","bP","bP","bP","bP","bP",
    null,null,null,null,null,null,null,null,
    null,null,null,null,null,null,null,null,
    null,null,null,null,null,null,null,null,
    null,null,null,null,null,null,null,null,
    "wP","wP","wP","wP","wP","wP","wP","wP",
    "wR","wN","wB","wQ","wK","wB","wN","wR"
  ]'::jsonb
$function$;

create or replace function public.book_chess_clear_path(p_board jsonb, p_from int, p_to int)
returns boolean
language plpgsql
immutable
as $function$
declare
  fr int := p_from / 8; fc int := p_from % 8;
  tr int := p_to / 8; tc int := p_to % 8;
  dr int := sign(tr-fr); dc int := sign(tc-fc);
  r int := fr + dr; c int := fc + dc;
begin
  while r <> tr or c <> tc loop
    if p_board->>(r*8+c) is not null then return false; end if;
    r := r + dr; c := c + dc;
  end loop;
  return true;
end
$function$;

create or replace function public.book_chess_attacked(p_board jsonb, p_sq int, p_by text)
returns boolean
language plpgsql
immutable
as $function$
declare
  i int; piece text; typ text;
  fr int; fc int; tr int := p_sq / 8; tc int := p_sq % 8;
  rd int; cd int;
begin
  for i in 0..63 loop
    piece := p_board->>i;
    if piece is null or left(piece,1) <> p_by then continue; end if;
    typ := right(piece,1); fr := i / 8; fc := i % 8;
    rd := tr-fr; cd := tc-fc;
    if typ='P' then
      if p_by='w' and rd=-1 and abs(cd)=1 then return true; end if;
      if p_by='b' and rd=1 and abs(cd)=1 then return true; end if;
    elsif typ='N' then
      if (abs(rd)=2 and abs(cd)=1) or (abs(rd)=1 and abs(cd)=2) then return true; end if;
    elsif typ='B' then
      if abs(rd)=abs(cd) and rd<>0 and public.book_chess_clear_path(p_board,i,p_sq) then return true; end if;
    elsif typ='R' then
      if ((rd=0 and cd<>0) or (cd=0 and rd<>0)) and public.book_chess_clear_path(p_board,i,p_sq) then return true; end if;
    elsif typ='Q' then
      if ((abs(rd)=abs(cd) and rd<>0) or (rd=0 and cd<>0) or (cd=0 and rd<>0))
         and public.book_chess_clear_path(p_board,i,p_sq) then return true; end if;
    elsif typ='K' then
      if greatest(abs(rd),abs(cd))=1 then return true; end if;
    end if;
  end loop;
  return false;
end
$function$;

create or replace function public.book_chess_in_check(p_board jsonb, p_colour text)
returns boolean
language plpgsql
immutable
as $function$
declare
  i int; king_sq int := null;
begin
  for i in 0..63 loop
    if p_board->>i = p_colour || 'K' then king_sq := i; exit; end if;
  end loop;
  if king_sq is null then return true; end if;
  return public.book_chess_attacked(p_board,king_sq,case when p_colour='w' then 'b' else 'w' end);
end
$function$;

create or replace function public.book_chess_apply_state(
  p_board jsonb, p_from int, p_to int, p_colour text,
  p_castling jsonb, p_en_passant int, p_promotion text default 'Q'
)
returns jsonb
language plpgsql
immutable
as $function$
declare
  b jsonb := p_board;
  rights jsonb := coalesce(p_castling,'{"wK":true,"wQ":true,"bK":true,"bQ":true}'::jsonb);
  piece text := p_board->>p_from;
  target text := p_board->>p_to;
  typ text := right(piece,1);
  fr int := p_from/8; fc int := p_from%8;
  tr int := p_to/8; tc int := p_to%8;
  ep int := null;
  cap_sq int;
  rook_from int; rook_to int; rook_piece text;
  promo text := upper(coalesce(nullif(p_promotion,''),'Q'));
begin
  if typ='P' and target is null and fc<>tc and p_en_passant is not null and p_to=p_en_passant then
    cap_sq := case when p_colour='w' then p_to+8 else p_to-8 end;
    b := jsonb_set(b,array[cap_sq::text],'null'::jsonb,false);
  end if;

  b := jsonb_set(b,array[p_from::text],'null'::jsonb,false);

  if typ='P' and ((p_colour='w' and tr=0) or (p_colour='b' and tr=7)) then
    if promo not in ('Q','R','B','N') then promo := 'Q'; end if;
    piece := p_colour || promo;
  end if;
  b := jsonb_set(b,array[p_to::text],to_jsonb(piece),false);

  if typ='K' and abs(tc-fc)=2 then
    if tc=6 then rook_from := fr*8+7; rook_to := fr*8+5;
    else rook_from := fr*8; rook_to := fr*8+3; end if;
    rook_piece := p_board->>rook_from;
    b := jsonb_set(b,array[rook_from::text],'null'::jsonb,false);
    b := jsonb_set(b,array[rook_to::text],to_jsonb(rook_piece),false);
  end if;

  if typ='K' then
    if p_colour='w' then
      rights := jsonb_set(jsonb_set(rights,'{wK}','false'::jsonb,true),'{wQ}','false'::jsonb,true);
    else
      rights := jsonb_set(jsonb_set(rights,'{bK}','false'::jsonb,true),'{bQ}','false'::jsonb,true);
    end if;
  elsif typ='R' then
    if p_from=63 then rights:=jsonb_set(rights,'{wK}','false'::jsonb,true); end if;
    if p_from=56 then rights:=jsonb_set(rights,'{wQ}','false'::jsonb,true); end if;
    if p_from=7 then rights:=jsonb_set(rights,'{bK}','false'::jsonb,true); end if;
    if p_from=0 then rights:=jsonb_set(rights,'{bQ}','false'::jsonb,true); end if;
  end if;

  if target='wR' and p_to=63 then rights:=jsonb_set(rights,'{wK}','false'::jsonb,true); end if;
  if target='wR' and p_to=56 then rights:=jsonb_set(rights,'{wQ}','false'::jsonb,true); end if;
  if target='bR' and p_to=7 then rights:=jsonb_set(rights,'{bK}','false'::jsonb,true); end if;
  if target='bR' and p_to=0 then rights:=jsonb_set(rights,'{bQ}','false'::jsonb,true); end if;

  if typ='P' and abs(tr-fr)=2 then ep := ((fr+tr)/2)*8+fc; end if;

  return jsonb_build_object('board',b,'castling',rights,'enPassant',ep);
end
$function$;

create or replace function public.book_chess_is_legal(
  p_board jsonb, p_from int, p_to int, p_colour text,
  p_castling jsonb, p_en_passant int, p_promotion text default 'Q'
)
returns boolean
language plpgsql
immutable
as $function$
declare
  piece text; target text; typ text;
  fr int; fc int; tr int; tc int; rd int; cd int; dir int; start_row int;
  ok boolean := false;
  enemy text := case when p_colour='w' then 'b' else 'w' end;
  rights jsonb := coalesce(p_castling,'{"wK":true,"wQ":true,"bK":true,"bQ":true}'::jsonb);
  state jsonb;
  key text;
begin
  if p_from<0 or p_from>63 or p_to<0 or p_to>63 or p_from=p_to then return false; end if;
  piece:=p_board->>p_from; target:=p_board->>p_to;
  if piece is null or left(piece,1)<>p_colour then return false; end if;
  if target is not null and (left(target,1)=p_colour or right(target,1)='K') then return false; end if;
  typ:=right(piece,1); fr:=p_from/8; fc:=p_from%8; tr:=p_to/8; tc:=p_to%8;
  rd:=tr-fr; cd:=tc-fc;

  if typ='P' then
    dir:=case when p_colour='w' then -1 else 1 end;
    start_row:=case when p_colour='w' then 6 else 1 end;
    if cd=0 and rd=dir and target is null then ok:=true;
    elsif cd=0 and rd=2*dir and fr=start_row and target is null and p_board->>((fr+dir)*8+fc) is null then ok:=true;
    elsif abs(cd)=1 and rd=dir and target is not null and left(target,1)=enemy then ok:=true;
    elsif abs(cd)=1 and rd=dir and target is null and p_en_passant is not null and p_to=p_en_passant
      and p_board->>(case when p_colour='w' then p_to+8 else p_to-8 end)=enemy||'P' then ok:=true;
    end if;
  elsif typ='N' then
    ok:=(abs(rd)=2 and abs(cd)=1) or (abs(rd)=1 and abs(cd)=2);
  elsif typ='B' then
    ok:=abs(rd)=abs(cd) and rd<>0 and public.book_chess_clear_path(p_board,p_from,p_to);
  elsif typ='R' then
    ok:=((rd=0 and cd<>0) or (cd=0 and rd<>0)) and public.book_chess_clear_path(p_board,p_from,p_to);
  elsif typ='Q' then
    ok:=((abs(rd)=abs(cd) and rd<>0) or (rd=0 and cd<>0) or (cd=0 and rd<>0))
      and public.book_chess_clear_path(p_board,p_from,p_to);
  elsif typ='K' then
    if greatest(abs(rd),abs(cd))=1 then
      ok:=true;
    elsif rd=0 and abs(cd)=2 then
      key:=p_colour||case when cd>0 then 'K' else 'Q' end;
      if not coalesce((rights->>key)::boolean,false) then return false; end if;
      if p_colour='w' and p_from<>60 then return false; end if;
      if p_colour='b' and p_from<>4 then return false; end if;
      if cd>0 then
        if p_board->>(fr*8+5) is not null or p_board->>(fr*8+6) is not null
           or p_board->>(fr*8+7)<>p_colour||'R' then return false; end if;
        if public.book_chess_in_check(p_board,p_colour)
           or public.book_chess_attacked(p_board,fr*8+5,enemy)
           or public.book_chess_attacked(p_board,fr*8+6,enemy) then return false; end if;
      else
        if p_board->>(fr*8+1) is not null or p_board->>(fr*8+2) is not null or p_board->>(fr*8+3) is not null
           or p_board->>(fr*8)<>p_colour||'R' then return false; end if;
        if public.book_chess_in_check(p_board,p_colour)
           or public.book_chess_attacked(p_board,fr*8+3,enemy)
           or public.book_chess_attacked(p_board,fr*8+2,enemy) then return false; end if;
      end if;
      ok:=true;
    end if;
  end if;

  if not ok then return false; end if;
  if typ='P' and ((p_colour='w' and tr=0) or (p_colour='b' and tr=7))
     and upper(coalesce(p_promotion,'Q')) not in ('Q','R','B','N') then return false; end if;

  state:=public.book_chess_apply_state(p_board,p_from,p_to,p_colour,rights,p_en_passant,p_promotion);
  return not public.book_chess_in_check(state->'board',p_colour);
end
$function$;

create or replace function public.book_chess_has_legal_move(
  p_board jsonb, p_colour text, p_castling jsonb, p_en_passant int
)
returns boolean
language plpgsql
immutable
as $function$
declare
  i int; j int; piece text;
begin
  for i in 0..63 loop
    piece:=p_board->>i;
    if piece is null or left(piece,1)<>p_colour then continue; end if;
    for j in 0..63 loop
      if public.book_chess_is_legal(p_board,i,j,p_colour,p_castling,p_en_passant,'Q') then return true; end if;
    end loop;
  end loop;
  return false;
end
$function$;

create or replace function public.book_chess_settle_189(p_data jsonb, p_idx int, p_winner text, p_reason text)
returns jsonb
language plpgsql
as $function$
declare
  d jsonb:=p_data; g jsonb; a text; b text; stake int;
  ra numeric; rb numeric; ea numeric; eb numeric; sa numeric; sb numeric;
  na int; nb int; now_ms bigint:=(extract(epoch from now())*1000)::bigint;
begin
  g:=d->'chess'->p_idx; a:=g->>'challenger'; b:=g->>'opponent'; stake:=coalesce((g->>'stake')::int,0);
  d:=jsonb_set(d,'{chips}',coalesce(d->'chips','{}'::jsonb),true);
  if stake>0 then
    if p_winner is null then
      d:=jsonb_set(d,array['chips',a],to_jsonb(coalesce((d->'chips'->>a)::int,1000)+stake),true);
      d:=jsonb_set(d,array['chips',b],to_jsonb(coalesce((d->'chips'->>b)::int,1000)+stake),true);
    else
      d:=jsonb_set(d,array['chips',p_winner],to_jsonb(coalesce((d->'chips'->>p_winner)::int,1000)+2*stake),true);
    end if;
  end if;

  d:=jsonb_set(d,'{chessRatings}',coalesce(d->'chessRatings','{}'::jsonb),true);
  ra:=coalesce((d->'chessRatings'->>a)::numeric,1200);
  rb:=coalesce((d->'chessRatings'->>b)::numeric,1200);
  ea:=1/(1+power(10,(rb-ra)/400.0)); eb:=1-ea;
  sa:=case when p_winner is null then .5 when p_winner=a then 1 else 0 end; sb:=1-sa;
  na:=greatest(100,round(ra+32*(sa-ea))::int); nb:=greatest(100,round(rb+32*(sb-eb))::int);
  d:=jsonb_set(d,array['chessRatings',a],to_jsonb(na),true);
  d:=jsonb_set(d,array['chessRatings',b],to_jsonb(nb),true);

  g:=g||jsonb_build_object(
    'status',case when p_winner is null then 'draw' else 'done' end,
    'winner',p_winner,'resultReason',p_reason,'doneAt',now_ms,'turn',null,'drawOffer',null,
    'ratingBefore',jsonb_build_object(a,round(ra)::int,b,round(rb)::int),
    'ratingAfter',jsonb_build_object(a,na,b,nb)
  );
  if g->'clock' is not null then g:=jsonb_set(g,'{clock,lastAt}','null'::jsonb,true); end if;
  d:=jsonb_set(d,array['chess',p_idx::text],g,true);
  d:=jsonb_set(d,'{log}',coalesce(d->'log','[]'::jsonb)||to_jsonb(
    case when p_winner is null then format('%s and %s drew at Chess (%s)',a,b,p_reason)
    else format('%s beat %s at Chess (%s)',p_winner,case when p_winner=a then b else a end,p_reason) end
  ),true);
  return d;
end
$function$;

create or replace function public.book_chess_action(p_name text, p_pin text, p_action jsonb)
returns integer
language plpgsql
security definer
set search_path = public, extensions
as $function$
declare
  d jsonb; v int; t text:=p_action->>'t'; g jsonb; i int; j int; idx int:=null;
  opp text; colour text; enemy text; winner text; tc text; piece text; state jsonb;
  stake int; cur int; from_sq int; to_sq int; now_ms bigint:=(extract(epoch from now())*1000)::bigint;
  base_ms int; inc_ms int; remaining bigint; elapsed bigint; last_at bigint;
  white_player text; black_player text;
begin
  if public.book_check(p_name,p_pin) is null then raise exception 'Wrong name or PIN'; end if;
  select data,version into d,v from public.book where id=1 for update;
  d:=jsonb_set(d,'{chess}',coalesce(d->'chess','[]'::jsonb),true);
  d:=jsonb_set(d,'{chessRatings}',coalesce(d->'chessRatings','{}'::jsonb),true);
  d:=jsonb_set(d,'{chips}',coalesce(d->'chips','{}'::jsonb),true);

  if t='chessCreate' then
    opp:=p_action->>'opponent';
    if opp is null or opp=p_name then raise exception 'Pick someone else to challenge.'; end if;
    if not exists(select 1 from jsonb_array_elements(coalesce(d->'players','[]'::jsonb)) x where x->>'name'=opp and coalesce((x->>'active')::boolean,false)) then
      raise exception 'That player is not active.';
    end if;
    tc:=coalesce(p_action->>'timeControl','blitz');
    if tc not in ('bullet','blitz','rapid','untimed') then raise exception 'Bad time control.'; end if;
    stake:=greatest(0,coalesce((p_action->>'stake')::int,0));
    cur:=coalesce((d->'chips'->>p_name)::int,1000);
    if stake>cur then raise exception 'You cannot stake more than your chip balance.'; end if;
    if exists(select 1 from jsonb_array_elements(d->'chess') x where x->>'status' in ('pending','playing')
      and (((x->>'challenger')=p_name and (x->>'opponent')=opp) or ((x->>'opponent')=p_name and (x->>'challenger')=opp))) then
      raise exception 'You already have a Chess game with them.';
    end if;
    if stake>0 then d:=jsonb_set(d,array['chips',p_name],to_jsonb(cur-stake),true); end if;
    d:=jsonb_set(d,'{chess}',d->'chess'||jsonb_build_array(jsonb_build_object(
      'id','ch'||now_ms::text,'challenger',p_name,'opponent',opp,'stake',stake,'timeControl',tc,
      'status','pending','winner',null,'turn',null,'board',public.book_chess_initial_board(),
      'castling','{"wK":true,"wQ":true,"bK":true,"bQ":true}'::jsonb,'enPassant',null,
      'history','[]'::jsonb,'drawOffer',null,'createdAt',now_ms
    )),true);

  elsif t in ('chessAccept','chessDecline','chessCancel','chessMove','chessResign','chessDrawOffer','chessDrawAccept','chessDrawDecline','chessClaimTimeout') then
    for j in 0..coalesce(jsonb_array_length(d->'chess'),0)-1 loop
      if d->'chess'->j->>'id'=p_action->>'id' then idx:=j; exit; end if;
    end loop;
    if idx is null then raise exception 'That Chess game is gone.'; end if;
    g:=d->'chess'->idx;
    if p_name<>g->>'challenger' and p_name<>g->>'opponent' then raise exception 'That is not your game.'; end if;

    if t='chessAccept' then
      if g->>'status'<>'pending' or g->>'opponent'<>p_name then raise exception 'That challenge cannot be accepted.'; end if;
      stake:=coalesce((g->>'stake')::int,0); cur:=coalesce((d->'chips'->>p_name)::int,1000);
      if stake>cur then raise exception 'You cannot stake more than your chip balance.'; end if;
      if stake>0 then d:=jsonb_set(d,array['chips',p_name],to_jsonb(cur-stake),true); end if;
      if random()<.5 then white_player:=g->>'challenger'; black_player:=g->>'opponent';
      else white_player:=g->>'opponent'; black_player:=g->>'challenger'; end if;
      tc:=g->>'timeControl';
      if tc='bullet' then base_ms:=60000; inc_ms:=0;
      elsif tc='blitz' then base_ms:=180000; inc_ms:=2000;
      elsif tc='rapid' then base_ms:=600000; inc_ms:=0;
      else base_ms:=null; inc_ms:=0; end if;
      g:=g||jsonb_build_object('status','playing','white',white_player,'black',black_player,'turn','w','startedAt',now_ms,'check',false,
        'clock',jsonb_build_object('w',case when base_ms is null then null else base_ms end,'b',case when base_ms is null then null else base_ms end,'inc',inc_ms,'lastAt',now_ms));
      d:=jsonb_set(d,array['chess',idx::text],g,true);

    elsif t in ('chessDecline','chessCancel') then
      if g->>'status'<>'pending' then raise exception 'That challenge has already started or finished.'; end if;
      if t='chessDecline' and g->>'opponent'<>p_name then raise exception 'That challenge is not for you.'; end if;
      if t='chessCancel' and g->>'challenger'<>p_name then raise exception 'That is not your challenge.'; end if;
      stake:=coalesce((g->>'stake')::int,0);
      if stake>0 then d:=jsonb_set(d,array['chips',g->>'challenger'],to_jsonb(coalesce((d->'chips'->>(g->>'challenger'))::int,1000)+stake),true); end if;
      g:=g||jsonb_build_object('status',case when t='chessDecline' then 'declined' else 'cancelled' end);
      d:=jsonb_set(d,array['chess',idx::text],g,true);

    else
      if g->>'status'<>'playing' then raise exception 'That Chess game is not in progress.'; end if;
      colour:=case when g->>'white'=p_name then 'w' else 'b' end;
      enemy:=case when colour='w' then 'b' else 'w' end;
      opp:=case when p_name=g->>'challenger' then g->>'opponent' else g->>'challenger' end;

      if t in ('chessMove','chessClaimTimeout') and g->'clock'->>colour is not null then
        last_at:=coalesce((g->'clock'->>'lastAt')::bigint,now_ms);
        elapsed:=greatest(0,now_ms-last_at);
        remaining:=greatest(0,(g->'clock'->>colour)::bigint-elapsed);
        if g->>'turn'=colour then g:=jsonb_set(g,array['clock',colour],to_jsonb(remaining),true); end if;
        if g->>'turn'=colour and remaining<=0 then
          d:=jsonb_set(d,array['chess',idx::text],g,true);
          d:=public.book_chess_settle_189(d,idx,opp,'timeout');
          update public.book set data=d,version=v+1,updated_at=now() where id=1; return v+1;
        end if;
      end if;

      if t='chessMove' then
        if g->>'turn'<>colour then raise exception 'It is not your turn.'; end if;
        from_sq:=(p_action->>'from')::int; to_sq:=(p_action->>'to')::int;
        if not public.book_chess_is_legal(g->'board',from_sq,to_sq,colour,g->'castling',nullif(g->>'enPassant','')::int,p_action->>'promotion') then
          raise exception 'Illegal move.';
        end if;
        piece:=g->'board'->>from_sq;
        state:=public.book_chess_apply_state(g->'board',from_sq,to_sq,colour,g->'castling',nullif(g->>'enPassant','')::int,p_action->>'promotion');
        g:=jsonb_set(g,'{board}',state->'board',true);
        g:=jsonb_set(g,'{castling}',state->'castling',true);
        g:=jsonb_set(g,'{enPassant}',coalesce(state->'enPassant','null'::jsonb),true);
        g:=jsonb_set(g,'{history}',coalesce(g->'history','[]'::jsonb)||jsonb_build_array(jsonb_build_object(
          'from',from_sq,'to',to_sq,'piece',piece,'promotion',upper(coalesce(nullif(p_action->>'promotion',''),'Q')),'at',now_ms
        )),true);
        if g->'clock'->>colour is not null then
          remaining:=coalesce((g->'clock'->>colour)::bigint,0)+coalesce((g->'clock'->>'inc')::int,0);
          g:=jsonb_set(g,array['clock',colour],to_jsonb(remaining),true);
          g:=jsonb_set(g,'{clock,lastAt}',to_jsonb(now_ms),true);
        end if;
        g:=jsonb_set(g,'{turn}',to_jsonb(enemy),true);
        g:=jsonb_set(g,'{drawOffer}','null'::jsonb,true);
        if not public.book_chess_has_legal_move(g->'board',enemy,g->'castling',nullif(g->>'enPassant','')::int) then
          d:=jsonb_set(d,array['chess',idx::text],g,true);
          if public.book_chess_in_check(g->'board',enemy) then d:=public.book_chess_settle_189(d,idx,p_name,'checkmate');
          else d:=public.book_chess_settle_189(d,idx,null,'stalemate'); end if;
        else
          g:=jsonb_set(g,'{check}',to_jsonb(public.book_chess_in_check(g->'board',enemy)),true);
          d:=jsonb_set(d,array['chess',idx::text],g,true);
        end if;

      elsif t='chessResign' then
        d:=public.book_chess_settle_189(d,idx,opp,'resignation');
      elsif t='chessDrawOffer' then
        if g->>'drawOffer' is not null then raise exception 'A draw offer is already open.'; end if;
        g:=jsonb_set(g,'{drawOffer}',to_jsonb(p_name),true); d:=jsonb_set(d,array['chess',idx::text],g,true);
      elsif t='chessDrawDecline' then
        if g->>'drawOffer' is null or g->>'drawOffer'=p_name then raise exception 'There is no draw offer for you to decline.'; end if;
        g:=jsonb_set(g,'{drawOffer}','null'::jsonb,true); d:=jsonb_set(d,array['chess',idx::text],g,true);
      elsif t='chessDrawAccept' then
        if g->>'drawOffer' is null or g->>'drawOffer'=p_name then raise exception 'There is no draw offer for you to accept.'; end if;
        d:=public.book_chess_settle_189(d,idx,null,'agreed draw');
      elsif t='chessClaimTimeout' then
        if g->'clock'->>(g->>'turn') is null then raise exception 'Untimed games cannot time out.'; end if;
        last_at:=coalesce((g->'clock'->>'lastAt')::bigint,now_ms);
        remaining:=(g->'clock'->>(g->>'turn'))::bigint-greatest(0,now_ms-last_at);
        if remaining>0 then raise exception 'Their clock is still running.'; end if;
        winner:=case when g->>'turn'='w' then g->>'black' else g->>'white' end;
        d:=public.book_chess_settle_189(d,idx,winner,'timeout');
      end if;
    end if;
  else
    raise exception 'Unknown Chess action.';
  end if;

  if jsonb_array_length(coalesce(d->'log','[]'::jsonb))>400 then
    d:=jsonb_set(d,'{log}',(select coalesce(jsonb_agg(value),'[]'::jsonb) from (
      select value from jsonb_array_elements(d->'log') with ordinality x(value,pos) order by pos desc limit 300
    ) q),true);
  end if;
  update public.book set data=d,version=v+1,updated_at=now() where id=1;
  return v+1;
end
$function$;

create or replace function public.book_player_xp(p_data jsonb, p_player text)
returns integer
language plpgsql
stable
as $function$
declare
  w jsonb; g jsonb; xp integer:=0; gd integer;
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
  select coalesce(sum(coalesce((x->>'xp')::int,0)),0)::int into gd from jsonb_array_elements(coalesce(p_data->'challengeClaims','[]'::jsonb)) x where x->>'player'=p_player;
  return xp+gd;
end
$function$;

create or replace function public.book_weekly_challenge_189(p_data jsonb, p_player text, p_key text)
returns jsonb
language plpgsql
stable
as $function$
declare
  d jsonb:=p_data; w jsonb; wn int; ci int; mi int;
  core text[]:=array['wins3','play4','diff10'];
  mini text[]:=array['c4wins2','bswin1','hogwin1','chesswin1'];
  active1 text; active2 text; active3 text; v int:=0; reward int:=0; xp_reward int:=0; target int:=0; challenge_start bigint:=0;
begin
  if jsonb_array_length(coalesce(d->'weeks','[]'::jsonb))=0 then return jsonb_build_object('active',false,'done',false); end if;
  w:=d->'weeks'->(jsonb_array_length(d->'weeks')-1); wn:=(w->>'n')::int;
  ci:=((wn-1)%3)+1; mi:=((wn-1)%4)+1;
  active1:=core[ci]; active2:=mini[mi]; active3:=core[(ci%3)+1];
  if p_key<>all(array[active1,active2,active3]) then return jsonb_build_object('active',false,'done',false,'week',wn); end if;
  challenge_start:=coalesce((d->>'challengeWeekStartedAt')::bigint,0);

  if p_key='wins3' then
    select count(*)::int into v from jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) x
    where x->>'s1' is not null and (((x->>'s1')::int>(x->>'s2')::int and x->>'p1'=p_player) or ((x->>'s2')::int>(x->>'s1')::int and x->>'p2'=p_player));
    reward:=10000; xp_reward:=750; target:=3;
  elsif p_key='play4' then
    select count(*)::int into v from jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) x where x->>'s1' is not null and (x->>'p1'=p_player or x->>'p2'=p_player);
    reward:=5000; xp_reward:=400; target:=4;
  elsif p_key='diff10' then
    select coalesce(sum(case when x->>'p1'=p_player then (x->>'s1')::int-(x->>'s2')::int else (x->>'s2')::int-(x->>'s1')::int end),0)::int into v
    from jsonb_array_elements(coalesce(w->'fixtures','[]'::jsonb)) x where x->>'s1' is not null and (x->>'p1'=p_player or x->>'p2'=p_player);
    reward:=7500; xp_reward:=750; target:=10;
  elsif p_key='c4wins2' then
    select count(*)::int into v from jsonb_array_elements(coalesce(d->'connect4','[]'::jsonb)) x where x->>'status'='done' and x->>'winner'=p_player
      and (coalesce((x->>'week')::int,-1)=wn or (x->>'week' is null and coalesce((x->>'createdAt')::bigint,0)>=challenge_start));
    reward:=5000; xp_reward:=500; target:=2;
  elsif p_key='bswin1' then
    select count(*)::int into v from jsonb_array_elements(coalesce(d->'battleships','[]'::jsonb)) x where x->>'status'='done' and x->>'winner'=p_player
      and (coalesce((x->>'week')::int,-1)=wn or (x->>'week' is null and coalesce((x->>'createdAt')::bigint,0)>=challenge_start));
    reward:=5000; xp_reward:=500; target:=1;
  elsif p_key='hogwin1' then
    select count(*)::int into v from jsonb_array_elements(coalesce(d->'hogDuels','[]'::jsonb)) x where x->>'status'='done' and x->>'winner'=p_player and coalesce((x->>'week')::int,-1)=wn;
    reward:=3000; xp_reward:=300; target:=1;
  elsif p_key='chesswin1' then
    select count(*)::int into v from jsonb_array_elements(coalesce(d->'chess','[]'::jsonb)) x where x->>'status'='done' and x->>'winner'=p_player
      and coalesce((x->>'createdAt')::bigint,0)>=challenge_start;
    reward:=5000; xp_reward:=500; target:=1;
  end if;
  return jsonb_build_object('active',true,'done',v>=target,'week',wn,'progress',v,'target',target,'reward',reward,'xp',xp_reward);
end
$function$;

create or replace function public.book_spin_wheel(p_name text, p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $function$
declare
  d jsonb; v int; last_spin bigint; now_ms bigint; roll numeric; amt int; stamp text; wait_mins int;
  segs jsonb; total_w numeric; cum numeric; seg jsonb; cooldown_mins int; cooldown_ms bigint;
  pending jsonb; spin_id text;
begin
  if public.book_check(p_name,p_pin) is null then raise exception 'Wrong name or PIN'; end if;
  select data,version into d,v from public.book where id=1 for update;
  now_ms:=(extract(epoch from now())*1000)::bigint;
  d:=jsonb_set(d,'{wheelPending}',coalesce(d->'wheelPending','{}'::jsonb),true);
  pending:=d->'wheelPending'->p_name;
  if pending is not null then
    return jsonb_build_object(
      'spinId',pending->>'id','amount',(pending->>'amount')::int,'next',(pending->>'next')::bigint,
      'cooldownMinutes',coalesce((pending->>'cooldownMinutes')::int,public.book_wheel_cooldown_minutes(d,p_name)),
      'resumed',true
    );
  end if;

  stamp:=to_char(now() at time zone 'Europe/London','DD Mon HH24:MI');
  cooldown_mins:=public.book_wheel_cooldown_minutes(d,p_name); cooldown_ms:=cooldown_mins*60000::bigint;
  last_spin:=nullif(d->'wheelSpins'->>p_name,'')::bigint;
  if last_spin is not null and now_ms-last_spin<cooldown_ms then
    wait_mins:=ceil((cooldown_ms-(now_ms-last_spin))/60000.0);
    raise exception 'Not ready yet, % minute% left.',wait_mins,case when wait_mins=1 then '' else 's' end;
  end if;
  segs:=d->'wheelSegments';
  if segs is null or jsonb_array_length(segs)=0 then
    segs:='[{"amount":1500,"weight":1},{"amount":750,"weight":2},{"amount":400,"weight":4},{"amount":250,"weight":8},{"amount":150,"weight":12},{"amount":100,"weight":18},{"amount":75,"weight":25},{"amount":50,"weight":30}]'::jsonb;
  end if;
  select sum((x->>'weight')::numeric) into total_w from jsonb_array_elements(segs) x; if total_w is null or total_w<=0 then total_w:=1; end if;
  roll:=random()*total_w; cum:=0; amt:=null;
  for seg in select * from jsonb_array_elements(segs) loop
    cum:=cum+coalesce((seg->>'weight')::numeric,0); if amt is null and roll<cum then amt:=(seg->>'amount')::int; end if;
  end loop;
  if amt is null then amt:=(segs->(jsonb_array_length(segs)-1)->>'amount')::int; end if;

  spin_id:='ws'||now_ms::text||floor(random()*100000)::int::text;
  d:=jsonb_set(d,'{wheelSpins}',coalesce(d->'wheelSpins','{}'::jsonb),true);
  d:=jsonb_set(d,array['wheelSpins',p_name],to_jsonb(now_ms),true);
  d:=jsonb_set(d,array['wheelPending',p_name],jsonb_build_object(
    'id',spin_id,'amount',amt,'createdAt',now_ms,'next',now_ms+cooldown_ms,'cooldownMinutes',cooldown_mins
  ),true);
  update public.book set data=d,version=v+1,updated_at=now() where id=1;
  return jsonb_build_object('spinId',spin_id,'amount',amt,'next',now_ms+cooldown_ms,'cooldownMinutes',cooldown_mins,'resumed',false);
end
$function$;

create or replace function public.book_claim_wheel(p_name text, p_pin text, p_spin_id text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $function$
declare
  d jsonb; v int; pending jsonb; amt int; wi int; stamp text;
begin
  if public.book_check(p_name,p_pin) is null then raise exception 'Wrong name or PIN'; end if;
  select data,version into d,v from public.book where id=1 for update;
  pending:=d->'wheelPending'->p_name;
  if pending is null then raise exception 'No wheel result is waiting.'; end if;
  if pending->>'id'<>p_spin_id then raise exception 'That wheel result is no longer current.'; end if;
  amt:=(pending->>'amount')::int; wi:=coalesce((d->'chips'->>p_name)::int,1000);
  d:=jsonb_set(d,'{chips}',coalesce(d->'chips','{}'::jsonb),true);
  d:=jsonb_set(d,array['chips',p_name],to_jsonb(wi+amt),true);
  d:=jsonb_set(d,array['wheelPending'],coalesce(d->'wheelPending','{}'::jsonb)-p_name,true);
  stamp:=to_char(now() at time zone 'Europe/London','DD Mon HH24:MI');
  d:=jsonb_set(d,'{log}',coalesce(d->'log','[]'::jsonb)||to_jsonb(stamp||' '||p_name||' spun the wheel and won '||amt||' chips'),true);
  update public.book set data=d,version=v+1,updated_at=now() where id=1;
  return jsonb_build_object('amount',amt,'next',(pending->>'next')::bigint,'cooldownMinutes',(pending->>'cooldownMinutes')::int);
end
$function$;

do $patch$
declare f text; original text;
begin
  select pg_get_functiondef(p.oid) into f
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='book_player_action'
  order by p.oid desc limit 1;
  if f is null then raise exception 'book_player_action not found'; end if;
  original:=f;
  f:=replace(f,'public.book_weekly_challenge_188','public.book_weekly_challenge_189');
  f:=replace(f,'< 12000 then raise exception ''Reach level 25 first.'';','< public.book_prestige_xp_required() then raise exception ''Reach level 25 first.'';');
  if f=original then raise exception 'book_player_action 1.8.9 patch found nothing to replace'; end if;
  if position('public.book_weekly_challenge_188' in f)>0 or position('< 12000 then raise exception ''Reach level 25 first.'';' in f)>0 then
    raise exception 'book_player_action 1.8.9 patch incomplete';
  end if;
  execute f;
end
$patch$;

update public.book
set data = jsonb_set(
  jsonb_set(
    jsonb_set(data,'{chess}',coalesce(data->'chess','[]'::jsonb),true),
    '{chessRatings}',coalesce(data->'chessRatings','{}'::jsonb),true
  ),
  '{wheelPending}',coalesce(data->'wheelPending','{}'::jsonb),true
), updated_at=now()
where id=1;

create or replace function public.book_version()
returns integer
language sql
as $function$
  select 31
$function$;

revoke all on function public.book_chess_initial_board() from public;
revoke all on function public.book_chess_clear_path(jsonb,int,int) from public;
revoke all on function public.book_chess_attacked(jsonb,int,text) from public;
revoke all on function public.book_chess_in_check(jsonb,text) from public;
revoke all on function public.book_chess_apply_state(jsonb,int,int,text,jsonb,int,text) from public;
revoke all on function public.book_chess_is_legal(jsonb,int,int,text,jsonb,int,text) from public;
revoke all on function public.book_chess_has_legal_move(jsonb,text,jsonb,int) from public;
revoke all on function public.book_chess_settle_189(jsonb,int,text,text) from public;
revoke all on function public.book_wheel_cooldown_minutes(jsonb,text) from public;
revoke all on function public.book_prestige_xp_required() from public;
revoke all on function public.book_weekly_challenge_189(jsonb,text,text) from public;
revoke all on function public.book_chess_action(text,text,jsonb) from public;
revoke all on function public.book_claim_wheel(text,text,text) from public;
grant execute on function public.book_chess_action(text,text,jsonb) to anon, authenticated, service_role;
grant execute on function public.book_claim_wheel(text,text,text) to anon, authenticated, service_role;
