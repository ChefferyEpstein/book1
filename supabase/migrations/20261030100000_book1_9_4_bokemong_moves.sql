-- Book1.9.4: varied, server-authoritative Bokémong move names, power and accuracy.
create or replace function public.book_bokemong_move_name_194(p_id text,p_move integer)
returns text language plpgsql immutable set search_path to 'public','extensions' as $$
declare t text := public.book_bokemong_type_191(p_id);
begin
 if p_move=3 then return case t
  when 'Machine' then 'Firewall' when 'Finance' then 'Hedge Position' when 'Regime' then 'Party Line'
  when 'Pool' then 'Safety Play' when 'Office' then 'Out of Office' when 'Arcade' then 'Pause Buffer'
  when 'Strategy' then 'Castle Up' when 'Abomination' then 'Feral Guard' when 'Degenerate' then 'Sick Day'
  when 'Work' then 'Mise en Place' else 'Brace' end; end if;
 return case t
  when 'Machine' then (array['Servo Smack','Overclock Surge','Critical Error'])[case p_move when 1 then 1 when 2 then 2 else 3 end]
  when 'Finance' then (array['Invoice Bite','Compound Interest','Audit Bomb'])[case p_move when 1 then 1 when 2 then 2 else 3 end]
  when 'Regime' then (array['Decree Slap','Red Stamp','Purge Protocol'])[case p_move when 1 then 1 when 2 then 2 else 3 end]
  when 'Pool' then (array['Chalk Jab','Bank Shot','Golden Break'])[case p_move when 1 then 1 when 2 then 2 else 3 end]
  when 'Office' then (array['Teams Ping','Reply All','Performance Review'])[case p_move when 1 then 1 when 2 then 2 else 3 end]
  when 'Arcade' then (array['Button Mash','Combo Chain','Final Boss'])[case p_move when 1 then 1 when 2 then 2 else 3 end]
  when 'Strategy' then (array['Pawn Prod','Fork Tactic','Mate Threat'])[case p_move when 1 then 1 when 2 then 2 else 3 end]
  when 'Abomination' then (array['Wet Slap','Mong Energy','Absolute State'])[case p_move when 1 then 1 when 2 then 2 else 3 end]
  when 'Degenerate' then (array['Smoke Break','Pub Maths','One More Pint'])[case p_move when 1 then 1 when 2 then 2 else 3 end]
  when 'Work' then (array['Pan Slap','Understaffed','SERVICE!'])[case p_move when 1 then 1 when 2 then 2 else 3 end]
  else 'Strike' end;
end $$;

create or replace function public.book_bokemong_move_power_194(p_id text,p_move integer)
returns integer language sql immutable set search_path to 'public','extensions' as $$
 select case p_move
 when 1 then case public.book_bokemong_type_191(p_id) when 'Machine' then 17 when 'Finance' then 19 when 'Regime' then 18 when 'Pool' then 16 when 'Office' then 15 when 'Arcade' then 17 when 'Strategy' then 16 when 'Abomination' then 20 when 'Degenerate' then 18 when 'Work' then 19 else 18 end
 when 2 then case public.book_bokemong_type_191(p_id) when 'Machine' then 29 when 'Finance' then 27 when 'Regime' then 30 when 'Pool' then 28 when 'Office' then 25 when 'Arcade' then 31 when 'Strategy' then 28 when 'Abomination' then 32 when 'Degenerate' then 30 when 'Work' then 27 else 28 end
 when 4 then case public.book_bokemong_type_191(p_id) when 'Machine' then 42 when 'Finance' then 40 when 'Regime' then 44 when 'Pool' then 39 when 'Office' then 38 when 'Arcade' then 43 when 'Strategy' then 41 when 'Abomination' then 46 when 'Degenerate' then 44 when 'Work' then 42 else 40 end
 else 0 end
$$;

create or replace function public.book_bokemong_move_accuracy_194(p_id text,p_move integer)
returns integer language sql immutable set search_path to 'public','extensions' as $$
 select case p_move
 when 1 then case public.book_bokemong_type_191(p_id) when 'Machine' then 98 when 'Finance' then 96 when 'Regime' then 99 when 'Pool' then 100 when 'Office' then 97 when 'Arcade' then 95 when 'Strategy' then 99 when 'Abomination' then 92 when 'Degenerate' then 94 when 'Work' then 97 else 98 end
 when 2 then case public.book_bokemong_type_191(p_id) when 'Machine' then 88 when 'Finance' then 91 when 'Regime' then 86 when 'Pool' then 93 when 'Office' then 90 when 'Arcade' then 84 when 'Strategy' then 92 when 'Abomination' then 82 when 'Degenerate' then 85 when 'Work' then 89 else 90 end
 when 3 then 100
 when 4 then case public.book_bokemong_type_191(p_id) when 'Machine' then 76 when 'Finance' then 72 when 'Regime' then 68 when 'Pool' then 80 when 'Office' then 82 when 'Arcade' then 70 when 'Strategy' then 74 when 'Abomination' then 65 when 'Degenerate' then 69 when 'Work' then 73 else 72 end
 else 0 end
$$;

do $$
declare src text;
begin
 select pg_get_functiondef('public.book_bokemong_action(text,text,jsonb)'::regprocedure) into src;
 src:=replace(src,'public.book_bokemong_move_name_191(mon->>''id'',move_no)','public.book_bokemong_move_name_194(mon->>''id'',move_no)');
 src:=replace(src,'acc:=case move_no when 1 then 100 when 2 then 92 else 72 end;','acc:=public.book_bokemong_move_accuracy_194(mon->>''id'',move_no);');
 src:=replace(src,'move_power:=case move_no when 1 then 18 when 2 then 26 else 38 end;','move_power:=public.book_bokemong_move_power_194(mon->>''id'',move_no);');
 execute src;
end $$;
