-- Book1 1.9.8 SQL v65: keep Tower Defense session tokens server-only.
DO $$
DECLARE f text;
BEGIN
 SELECT pg_get_functiondef('public.book_client_state()'::regprocedure) INTO f;
 f:=replace(f,
  'ARRAY[''battleships'',''connect4'',''chess'',''bets'',''bokemongs'',''pinballSessions'',''log'']::text[]',
  'ARRAY[''battleships'',''connect4'',''chess'',''bets'',''bokemongs'',''pinballSessions'',''towerDefenseSessions'',''log'']::text[]');
 IF f NOT LIKE '%towerDefenseSessions%text[]%' THEN RAISE EXCEPTION 'Could not harden client state for Tower Defense sessions'; END IF;
 EXECUTE f;
END $$;
