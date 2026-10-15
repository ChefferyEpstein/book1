-- Book1 1.9.1 — Bokémong theme cleanup
-- Keeps the live combat engine aligned with the client-side roster/theme.

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
    when 'pub-lich' then 'Degenerate'
    when 'bookie-rat' then 'Degenerate'
    when 'kitchen-ogre' then 'Work'
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
    when 'Degenerate' then (array['Smoke Break','Pub Maths','Sick Day','One More Pint'])[p_move]
    when 'Work' then (array['Pan Slap','Understaffed','Mise en Place','SERVICE!'])[p_move]
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
    when p_attacker='Degenerate' and p_defender='Work' then 1.25
    when p_attacker='Work' and p_defender='Office' then 1.25
    when p_attacker='Arcade' and p_defender='Strategy' then 1.25
    when p_attacker='Strategy' and p_defender='Arcade' then 1.25
    when p_defender='Pool' and p_attacker='Office' then 0.80
    when p_defender='Office' and p_attacker='Finance' then 0.80
    when p_defender='Finance' and p_attacker='Regime' then 0.80
    when p_defender='Regime' and p_attacker='Pool' then 0.80
    else 1.00
  end
$function$;

commit;
