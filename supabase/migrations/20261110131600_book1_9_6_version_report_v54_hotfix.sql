-- Keep the database version report aligned with the v54 schema and app client.
create or replace function public.book_version()
returns integer
language sql
set search_path to 'public', 'extensions'
as $function$
  select 54
$function$;
