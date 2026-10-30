-- Book1 v42: optimise the startup snapshot without changing stored data or the RPC contract.
-- This is a read-payload-only change. The source public.book.data is never updated.

CREATE OR REPLACE FUNCTION public.book_client_state()
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path TO 'public', 'extensions'
AS $function$
  WITH source AS MATERIALIZED (
    SELECT b.version, b.data
    FROM public.book AS b
    WHERE b.id = 1
  ),
  slim AS (
    SELECT
      s.version,
      -- Strip all transformed top-level keys in one operation. Their slim
      -- replacements are assembled separately and merged back exactly once.
      s.data - ARRAY[
        'battleships',
        'connect4',
        'chess',
        'bets',
        'bokemongs',
        'pinballSessions',
        'log'
      ]::text[] AS base_data,
      COALESCE((
        SELECT jsonb_agg(
          CASE
            WHEN g.elem->>'status' = 'done'
              THEN g.elem - 'shots' - 'sunk' - 'ready' - 'ships'
            ELSE g.elem
          END
          ORDER BY g.ord
        )
        FROM jsonb_array_elements(COALESCE(s.data->'battleships', '[]'::jsonb))
          WITH ORDINALITY AS g(elem, ord)
      ), '[]'::jsonb) AS battleships,
      COALESCE((
        SELECT jsonb_agg(
          CASE
            WHEN g.elem->>'status' IN ('done', 'draw')
              THEN (g.elem - 'history' - 'board') || jsonb_build_object(
                'moves',
                (SELECT count(*)
                 FROM jsonb_array_elements(COALESCE(g.elem->'board', '[]'::jsonb)) AS c
                 WHERE c <> 'null'::jsonb)
              )
            ELSE g.elem
          END
          ORDER BY g.ord
        )
        FROM jsonb_array_elements(COALESCE(s.data->'connect4', '[]'::jsonb))
          WITH ORDINALITY AS g(elem, ord)
      ), '[]'::jsonb) AS connect4,
      COALESCE((
        SELECT jsonb_agg(
          CASE
            WHEN g.elem->>'status' IN ('done', 'draw')
              THEN g.elem - 'history'
            ELSE g.elem
          END
          ORDER BY g.ord
        )
        FROM jsonb_array_elements(COALESCE(s.data->'chess', '[]'::jsonb))
          WITH ORDINALITY AS g(elem, ord)
      ), '[]'::jsonb) AS chess,
      COALESCE((
        SELECT jsonb_agg(g.elem ORDER BY g.ord)
        FROM jsonb_array_elements(COALESCE(s.data->'bets', '[]'::jsonb))
          WITH ORDINALITY AS g(elem, ord)
        WHERE g.elem->>'status' = 'open'
      ), '[]'::jsonb) AS bets,
      COALESCE((
        SELECT jsonb_agg(
          CASE
            WHEN g.elem->>'status' IN ('pending', 'playing')
              THEN g.elem
            ELSE g.elem - 'teams' - 'log'
          END
          ORDER BY g.ord
        )
        FROM jsonb_array_elements(
          COALESCE(s.data->'bokemongs'->'battles', '[]'::jsonb)
        ) WITH ORDINALITY AS g(elem, ord)
      ), '[]'::jsonb) AS bokemong_battles,
      COALESCE((
        SELECT jsonb_agg(g.elem ORDER BY g.ord)
        FROM jsonb_array_elements(COALESCE(s.data->'pinballSessions', '[]'::jsonb))
          WITH ORDINALITY AS g(elem, ord)
        WHERE g.elem->>'status' = 'playing'
      ), '[]'::jsonb) AS pinball_sessions,
      COALESCE((
        SELECT jsonb_agg(g.elem ORDER BY g.ord)
        FROM jsonb_array_elements(COALESCE(s.data->'log', '[]'::jsonb))
          WITH ORDINALITY AS g(elem, ord)
        WHERE g.ord > GREATEST(
          jsonb_array_length(COALESCE(s.data->'log', '[]'::jsonb)) - 200,
          0
        )
      ), '[]'::jsonb) AS recent_log,
      COALESCE(s.data->'bokemongs', '{}'::jsonb) AS bokemongs_base
    FROM source AS s
  ),
  payload AS (
    SELECT
      version,
      base_data || jsonb_build_object(
        'battleships', battleships,
        'connect4', connect4,
        'chess', chess,
        'bets', bets,
        'bokemongs', bokemongs_base || jsonb_build_object('battles', bokemong_battles),
        'pinballSessions', pinball_sessions,
        'log', recent_log
      ) AS data
    FROM slim
  )
  SELECT jsonb_build_object('data', data, 'version', version)
  FROM payload;
$function$;

REVOKE ALL ON FUNCTION public.book_client_state() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.book_client_state() TO anon, authenticated;
