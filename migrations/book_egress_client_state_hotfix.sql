-- Book1 egress hotfix
-- Keep full history in public.book, but expose a slimmed client snapshot.

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
              then g.elem - 'history'
            else g.elem
          end
          order by g.ord
        )
        from jsonb_array_elements(coalesce(b.data->'connect4','[]'::jsonb))
             with ordinality as g(elem, ord)
      ), '[]'::jsonb),
      true
    ),
    'version', b.version
  )
  from public.book b
  where b.id = 1
$function$;

grant execute on function public.book_client_state() to anon, authenticated;
