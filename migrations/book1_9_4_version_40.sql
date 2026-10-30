CREATE OR REPLACE FUNCTION public.book_version()
 RETURNS integer
 LANGUAGE sql
 SET search_path TO 'public', 'extensions'
AS $function$ select 40 $function$
