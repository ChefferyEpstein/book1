-- Book1 1.9.8 SQL v66: align the server-reported function version with deployed Tower Defense functions.
CREATE OR REPLACE FUNCTION public.book_version()
RETURNS integer
LANGUAGE sql
SET search_path TO 'public', 'extensions'
AS $function$ SELECT 66 $function$;
