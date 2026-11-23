-- Book1.9.8: award the hidden Diamond-Studded Goat when a player completes
-- the standard calling-card collection. The secret card is never part of case drops.
DO $migration$
DECLARE
  v_definition text;
  v_old text := $old$  d := jsonb_set(d, array['cards', p_name, 'owned'], (d->'cards'->p_name->'owned') || jsonb_build_array(picked->>'id'));$old$;
  v_new text := $new$  d := jsonb_set(d, array['cards', p_name, 'owned'], (d->'cards'->p_name->'owned') || jsonb_build_array(picked->>'id'));
  if not exists (
    select 1
    from jsonb_array_elements(cat) c
    where not coalesce((d->'cards'->p_name->'owned') ? (c->>'id'), false)
  ) and not coalesce((d->'cards'->p_name->'owned') ? 'diamond_goat', false) then
    d := jsonb_set(d, array['cards', p_name, 'owned'], (d->'cards'->p_name->'owned') || jsonb_build_array('diamond_goat'));
  end if;$new$;
BEGIN
  SELECT pg_get_functiondef('public.book_open_case(text,text)'::regprocedure)
  INTO v_definition;
  IF position('diamond_goat' IN v_definition) = 0 THEN
    IF position(v_old IN v_definition) = 0 THEN
      RAISE EXCEPTION 'Could not locate the owned-card update in book_open_case; no change made';
    END IF;
    v_definition := replace(v_definition, v_old, v_new);
    EXECUTE v_definition;
  END IF;
END
$migration$;

-- Award it to any existing player who already owns the complete standard set.
UPDATE public.book b
SET data = jsonb_set(
  b.data,
  ARRAY['cards', owned.player_name, 'owned'],
  coalesce(owned.card_state->'owned', '[]'::jsonb) || jsonb_build_array('diamond_goat'),
  true
)
FROM (
  SELECT c.key AS player_name, c.value AS card_state
  FROM public.book b0
  CROSS JOIN LATERAL jsonb_each(coalesce(b0.data->'cards', '{}'::jsonb)) c
  WHERE coalesce(c.value->'owned', '[]'::jsonb) ?| ARRAY(
    SELECT card->>'id'
    FROM jsonb_array_elements(coalesce(b0.data->'cardCatalog', '[]'::jsonb)) card
  )
  AND NOT coalesce(c.value->'owned', '[]'::jsonb) ? 'diamond_goat'
  AND NOT EXISTS (
    SELECT 1
    FROM jsonb_array_elements(coalesce(b0.data->'cardCatalog', '[]'::jsonb)) card
    WHERE NOT coalesce(c.value->'owned', '[]'::jsonb) ? (card->>'id')
  )
) owned
WHERE b.id = 1;

CREATE OR REPLACE FUNCTION public.book_version()
RETURNS integer
LANGUAGE sql
STABLE
SET search_path TO 'public', 'extensions'
AS $function$ SELECT 84; $function$;
