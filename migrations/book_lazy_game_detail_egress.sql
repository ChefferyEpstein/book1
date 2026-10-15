-- Lazy-load completed game detail to reduce Book1 client egress.

create or replace function public.book_game_detail(p_kind text, p_id text)
returns jsonb
language sql
stable
security invoker
set search_path = public, extensions
as $function$
  select case lower(p_kind)
    when 'connect4' then (
      select g
      from public.book b,
           lateral jsonb_array_elements(coalesce(b.data->'connect4','[]'::jsonb)) g
      where b.id = 1 and g->>'id' = p_id
      limit 1
    )
    when 'chess' then (
      select g
      from public.book b,
           lateral jsonb_array_elements(coalesce(b.data->'chess','[]'::jsonb)) g
      where b.id = 1 and g->>'id' = p_id
      limit 1
    )
    when 'battleships' then (
      select g
      from public.book b,
           lateral jsonb_array_elements(coalesce(b.data->'battleships','[]'::jsonb)) g
      where b.id = 1 and g->>'id' = p_id
      limit 1
    )
    else null
  end
$function$;

grant execute on function public.book_game_detail(text,text) to anon, authenticated;

create or replace function public.book_client_state()
returns jsonb
language sql
stable
security invoker
set search_path = public, extensions
as $function$
  select jsonb_build_object(
    'data',
    jsonb_set(
      jsonb_set(
        jsonb_set(
          b.data,
          '{battleships}',
          coalesce((
            select jsonb_agg(
              case
                when g.elem->>'status' = 'done'
                  then g.elem - 'shots' - 'sunk' - 'ready' - 'ships'
                else g.elem
              end
              order by g.ord
            )
            from jsonb_array_elements(coalesce(b.data->'battleships','[]'::jsonb))
                 with ordinality as g(elem, ord)
          ), '[]'::jsonb),
          true
        ),
        '{connect4}',
        coalesce((
          select jsonb_agg(
            case
              when g.elem->>'status' in ('done','draw')
                then (g.elem - 'history' - 'board')
                     || jsonb_build_object(
                          'moves',
                          (select count(*)
                           from jsonb_array_elements(coalesce(g.elem->'board','[]'::jsonb)) c
                           where c <> 'null'::jsonb)
                        )
              else g.elem
            end
            order by g.ord
          )
          from jsonb_array_elements(coalesce(b.data->'connect4','[]'::jsonb))
               with ordinality as g(elem, ord)
        ), '[]'::jsonb),
        true
      ),
      '{chess}',
      coalesce((
        select jsonb_agg(
          case
            when g.elem->>'status' in ('done','draw')
              then g.elem - 'history'
            else g.elem
          end
          order by g.ord
        )
        from jsonb_array_elements(coalesce(b.data->'chess','[]'::jsonb))
             with ordinality as g(elem, ord)
      ), '[]'::jsonb),
      true
    ),
    'version', b.version
  )
  from public.book b
  where b.id = 1
$function$;
