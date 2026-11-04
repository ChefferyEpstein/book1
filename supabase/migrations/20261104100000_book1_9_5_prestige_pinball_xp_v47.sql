do $patch$
declare
  f text;
  original text;
begin
  select pg_get_functiondef(p.oid) into f
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='book_player_xp'
  order by p.oid desc
  limit 1;

  if f is null then
    raise exception 'book_player_xp not found';
  end if;

  original := f;
  f := replace(
    f,
    'return xp+gd+bd;',
    $replacement$return xp+gd+bd+(
      select coalesce(sum(floor(greatest(0,coalesce((x->>'score')::numeric,0))/1000)),0)::int
      from jsonb_array_elements(coalesce(p_data->'pinballScores','[]'::jsonb)) x
      where x->>'player'=p_player
    );$replacement$
  );

  if f = original or position('p_data->''pinballScores''' in f)=0 then
    raise exception 'book_player_xp Pinball XP patch incomplete';
  end if;

  execute f;
end
$patch$;

create or replace function public.book_version()
returns integer
language sql
set search_path = public, extensions
as $function$
  select 47
$function$;
