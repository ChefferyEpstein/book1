-- Book1.9.4 hotfix: report SQL API version 43 after the Pinball score-cap update.
create or replace function public.book_version()
returns integer
language sql
stable
set search_path to 'public','extensions'
as $$
  select 43;
$$;