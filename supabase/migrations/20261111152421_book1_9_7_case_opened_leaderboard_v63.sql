do $$
declare
  v_counts jsonb;
  v_fn text;
begin
  select coalesce(jsonb_object_agg(p.name, to_jsonb(coalesce(c.total, 0))), '{}'::jsonb)
    into v_counts
  from public.players p
  left join (
    select substring(entry from '^[0-9]{1,2} [A-Z][a-z]{2} [0-9]{2}:[0-9]{2} (.+) opened a case:') as player_name,
           count(*)::integer as total
    from public.book b
    cross join lateral jsonb_array_elements_text(coalesce(b.data->'log', '[]'::jsonb)) as log_entries(entry)
    where position(' opened a case:' in entry) > 0
    group by 1
  ) c on c.player_name = p.name;

  update public.book
     set data = jsonb_set(coalesce(data, '{}'::jsonb), '{caseOpens}', v_counts, true),
         updated_at = now()
   where id = 1;

  select pg_get_functiondef('public.book_open_case(text,text)'::regprocedure) into v_fn;
  if position('d := jsonb_set(d, ''{log}'',' in v_fn) = 0 then
    raise exception 'Could not locate the case-opening log update; refusing to patch book_open_case';
  end if;
  v_fn := replace(
    v_fn,
    'd := jsonb_set(d, ''{log}'',',
    'd := jsonb_set(d, array[''caseOpens'', p_name], to_jsonb(coalesce((d->''caseOpens''->>p_name)::int, 0) + 1), true);' || E'\n  ' ||
    'd := jsonb_set(d, ''{log}'','
  );
  execute v_fn;

  execute $version$
    create or replace function public.book_version()
    returns integer
    language sql
    set search_path to 'public', 'extensions'
    as $body$ select 63 $body$
  $version$;
end
$$;