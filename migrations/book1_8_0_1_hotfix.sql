-- Book1 1.8.0.1 hotfix (DB v28)
-- Fix Connect 4 false-positive wins where an empty start cell plus three pieces
-- could be treated as four because SQL NULL comparison semantics caused the
-- starting-cell guard not to continue.
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
  if p_player is null
     or jsonb_typeof(p_board) <> 'array'
     or jsonb_array_length(p_board) <> 42 then
    return false;
  end if;

  for r in 0..5 loop
    for c in 0..6 loop
      -- NULL-safe: an empty JSON cell must never be treated as the player's piece.
      if (p_board->>(r*7+c)) is distinct from p_player then
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

create or replace function public.book_version()
returns integer
language sql
as $function$
  select 28
$function$;

commit;

-- Verification:
-- database_function_version = 28
-- connect3_false = false
-- connect4_true = true
select
  public.book_version() as database_function_version,
  public.book_c4_winner(
    '[
      null,"Chef","Chef","Chef",null,null,null,
      null,null,null,null,null,null,null,
      null,null,null,null,null,null,null,
      null,null,null,null,null,null,null,
      null,null,null,null,null,null,null,
      null,null,null,null,null,null,null
    ]'::jsonb,
    'Chef'
  ) as connect3_false,
  public.book_c4_winner(
    '[
      "Chef","Chef","Chef","Chef",null,null,null,
      null,null,null,null,null,null,null,
      null,null,null,null,null,null,null,
      null,null,null,null,null,null,null,
      null,null,null,null,null,null,null,
      null,null,null,null,null,null,null
    ]'::jsonb,
    'Chef'
  ) as connect4_true;
