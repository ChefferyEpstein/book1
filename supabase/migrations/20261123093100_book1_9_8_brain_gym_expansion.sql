-- Extend the existing server-side Brain Gym claim validator without changing the
-- original Sudoku, crossword, teaser rewards or the original-trio clear bonus.
do $brain_gym_expand$
declare
  v_definition text;
  v_old text;
  v_extra text := $extra$
 elsif p_type='anagram' then
  xp_award:=100;
  expected:=case (day_no % 12)
    when 0 then 'plate' when 1 then 'zebra' when 2 then 'lemon' when 3 then 'stare'
    when 4 then 'watch' when 5 then 'grape' when 6 then 'paint' when 7 then 'trace'
    when 8 then 'award' when 9 then 'beard' when 10 then 'could' when 11 then 'thing' end;
  if answer_norm<>expected then raise exception 'Not quite. Keep thinking.'; end if;
 elsif p_type='sequence' then
  xp_award:=100;
  expected:=case (day_no % 12)
    when 0 then '32' when 1 then '27' when 2 then '8' when 3 then '66'
    when 4 then '80' when 5 then '26' when 6 then '25' when 7 then '4'
    when 8 then '44' when 9 then '49' when 10 then '17' when 11 then '1' end;
  if answer_norm<>expected then raise exception 'Not quite. Keep thinking.'; end if;
 elsif p_type='logic' then
  xp_award:=100;
  expected:=case (day_no % 12)
    when 0 then '9' when 1 then '3' when 2 then '2' when 3 then '3'
    when 4 then '75' when 5 then '2' when 6 then '5' when 7 then '20'
    when 8 then '19' when 9 then '3' when 10 then '5' when 11 then '12' end;
  if answer_norm<>expected then raise exception 'Not quite. Keep thinking.'; end if;
 elsif p_type='memory' then
  xp_award:=100;
  expected:=case (day_no % 12)
    when 0 then 'r7k2m' when 1 then 'p4t9b' when 2 then '6h2q8' when 3 then 'c3n7f'
    when 4 then 'w8d5l' when 5 then '2j9rx' when 6 then 'm6v1a' when 7 then 't5p8c'
    when 8 then '9b3kh' when 9 then 'f2r7n' when 10 then 'l4x8d' when 11 then 'q7m2p' end;
  if answer_norm<>expected then raise exception 'Not quite. Keep thinking.'; end if;
$extra$;
begin
  select pg_get_functiondef('public.book_brain_claim(text,text,text,text,text)'::regprocedure)
    into v_definition;
  v_old := $old$if p_type not in ('sudoku','crossword','teaser') then$old$;
  if position(v_old in v_definition)=0 then raise exception 'Brain Gym claim whitelist did not match; no change applied.'; end if;
  v_definition := replace(v_definition,v_old,
    $new$if p_type not in ('sudoku','crossword','teaser','anagram','sequence','logic','memory') then$new$);
  v_old := $old$ else
  xp_award:=150;
  if (day_no % 25)=0 then$old$;
  if position(v_old in v_definition)=0 then raise exception 'Brain Gym teaser branch did not match; no change applied.'; end if;
  v_definition := replace(v_definition,v_old,
    $new$ elsif p_type='teaser' then
  xp_award:=150;
  if (day_no % 25)=0 then$new$);
  v_old := $old$
 end if;
 d:=jsonb_set(d,'{brainClaims}',(d->'brainClaims')||jsonb_build_array$new$;
  if position(v_old in v_definition)=0 then raise exception 'Brain Gym validation insertion point did not match; no change applied.'; end if;
  v_definition := replace(v_definition,v_old,v_extra||v_old);
  execute v_definition;
end
$brain_gym_expand$;
