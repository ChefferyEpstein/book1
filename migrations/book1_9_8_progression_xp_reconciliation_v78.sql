-- Book1 1.9.8: correct initial XP reconciliation after v77 (SQL v78)
-- v77 established the live ledger. The old manual 4,400 carryover overlapped pre-prestige claims.
-- Verified post-P5 rewards total 2,230 XP: 1,800 weekly claims, 80 Pinball,
-- 150 Connect 4, 150 Battleships, and 50 XP from two post-P5 common cases.
DROP TRIGGER IF EXISTS book_sync_xp_balance_trigger ON public.book;

UPDATE public.book
SET data=jsonb_set(
  data,
  '{progression,Lorcan}',
  (coalesce(data->'progression'->'Lorcan','{}'::jsonb)
    - 'xpCarry')
    || jsonb_build_object(
      'xpBalance',2230,
      'xpRawCheckpoint',public.book_player_xp(data,'Lorcan'),
      'xpCarry',0
    ),
  true
),
version=version+1,
updated_at=now()
WHERE id=1
  AND coalesce((data->'progression'->'Lorcan'->>'prestige')::integer,0)=5;

CREATE TRIGGER book_sync_xp_balance_trigger
BEFORE UPDATE OF data ON public.book
FOR EACH ROW EXECUTE FUNCTION public.book_sync_xp_balance();

CREATE OR REPLACE FUNCTION public.book_version()
RETURNS integer LANGUAGE sql STABLE SET search_path TO 'public','extensions'
AS $function$ SELECT 78; $function$;
