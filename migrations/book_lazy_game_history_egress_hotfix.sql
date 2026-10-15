-- Further egress reduction: trim completed-game payloads from normal client state
-- and lazy-load one historical game only when a user explicitly opens it.

create or replace function public.book_client_state()
returns jsonb
language sql
stable
security invoker
set search_path = public, extensions
as $function$
  with b as (
    select data, version from public.book where id = 1
  ),
  bs as (
    select coalesce(jsonb_agg(
      case
        when g.elem->>'status' = 'done'
          then g.elem - 'shots' - 'sunk' - 'ready' - 'ships'
        else g.elem
      end order by g.ord
    ), '[]'::jsonb) as v
    from b, jsonb_array_elements(coalesce(data->'battleships','[]'::jsonb))
      with ordinality as g(elem,ord)
  ),
  c4 as (
    select coalesce(jsonb_agg(
      case
        when g.elem->>'status' in ('done','draw') then
          (g.elem - 'history' - 'board') ||
          jsonb_build_object(
            'moveCount',
            (select count(*)
             from jsonb_array_elements(coalesce(g.elem->'board','[]'::jsonb)) x
             where x <> 'null'::jsonb)
          )
        else g.elem
      end order by g.ord
    ), '[]'::jsonb) as v
    from b, jsonb_array_elements(coalesce(data->'connect4','[]'::jsonb))
      with ordinality as g(elem,ord)
  ),
  ch as (
    select coalesce(jsonb_agg(
      case
        when g.elem->>'status' in ('done','draw')
          then g.elem - 'history'
        else g.elem
      end order by g.ord
    ), '[]'::jsonb) as v
    from b, jsonb_array_elements(coalesce(data->'chess','[]'::jsonb))
      with ordinality as g(elem,ord)
  )
  select jsonb_build_object(
    'data',
      jsonb_set(
        jsonb_set(
          jsonb_set(b.data,'{battleships}',bs.v,true),
          '{connect4}',c4.v,true
        ),
        '{chess}',ch.v,true
      ),
    'version', b.version
  )
  from b, bs, c4, ch
$function$;

create or replace function public.book_game_detail(p_kind text, p_id text)
returns jsonb
language sql
stable
security invoker
set search_path = public, extensions
as $function$
  select g.elem
  from public.book b,
       lateral jsonb_array_elements(
         case p_kind
           when 'connect4' then coalesce(b.data->'connect4','[]'::jsonb)
           when 'chess' then coalesce(b.data->'chess','[]'::jsonb)
           when 'battleships' then coalesce(b.data->'battleships','[]'::jsonb)
           else '[]'::jsonb
         end
       ) as g(elem)
  where b.id = 1
    and g.elem->>'id' = p_id
  limit 1
$function$;

grant execute on function public.book_game_detail(text,text) to anon, authenticated;
