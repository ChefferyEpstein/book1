-- Lazy-load settled bet history so normal Book sync only carries open bets.

create or replace function public.book_preserve_game_archives(p_current jsonb, p_incoming jsonb)
returns jsonb
language sql
stable
security invoker
set search_path = public, extensions
as $function$
with
c4 as (
  select coalesce(jsonb_agg(
    coalesce((
      select oldg
      from jsonb_array_elements(coalesce(p_current->'connect4','[]'::jsonb)) oldg
      where oldg->>'id' = newg.elem->>'id'
      limit 1
    ), '{}'::jsonb) || (newg.elem - 'moves')
    order by newg.ord
  ), '[]'::jsonb) as v
  from jsonb_array_elements(coalesce(p_incoming->'connect4','[]'::jsonb))
       with ordinality as newg(elem,ord)
),
ch as (
  select coalesce(jsonb_agg(
    coalesce((
      select oldg
      from jsonb_array_elements(coalesce(p_current->'chess','[]'::jsonb)) oldg
      where oldg->>'id' = newg.elem->>'id'
      limit 1
    ), '{}'::jsonb) || newg.elem
    order by newg.ord
  ), '[]'::jsonb) as v
  from jsonb_array_elements(coalesce(p_incoming->'chess','[]'::jsonb))
       with ordinality as newg(elem,ord)
),
bs as (
  select coalesce(jsonb_agg(
    coalesce((
      select oldg
      from jsonb_array_elements(coalesce(p_current->'battleships','[]'::jsonb)) oldg
      where oldg->>'id' = newg.elem->>'id'
      limit 1
    ), '{}'::jsonb) || newg.elem
    order by newg.ord
  ), '[]'::jsonb) as v
  from jsonb_array_elements(coalesce(p_incoming->'battleships','[]'::jsonb))
       with ordinality as newg(elem,ord)
)
select jsonb_set(
         jsonb_set(
           jsonb_set(
             jsonb_set(p_current || p_incoming, '{connect4}', c4.v, true),
             '{chess}', ch.v, true
           ),
           '{battleships}', bs.v, true
         ),
         '{bets}', coalesce(p_current->'bets','[]'::jsonb), true
       )
from c4,ch,bs
$function$;

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
      '{bets}',
      coalesce((
        select jsonb_agg(g.elem order by g.ord)
        from jsonb_array_elements(coalesce(b.data->'bets','[]'::jsonb))
             with ordinality as g(elem,ord)
        where g.elem->>'status' = 'open'
      ), '[]'::jsonb),
      true
    ),
    'version', b.version
  )
  from public.book b
  where b.id = 1
$function$;

create or replace function public.book_my_bets(p_name text, p_pin text, p_limit integer default 15)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, extensions
as $function$
declare
  out_data jsonb;
begin
  if book_check(p_name, p_pin) is null then
    raise exception 'Bad PIN';
  end if;

  select coalesce(jsonb_agg(q.bet order by q.placed desc), '[]'::jsonb)
  into out_data
  from (
    select b as bet,
           coalesce((b->>'placedAt')::bigint, 0) as placed
    from public.book x,
         lateral jsonb_array_elements(coalesce(x.data->'bets','[]'::jsonb)) b
    where x.id = 1
      and b->>'player' = p_name
    order by coalesce((b->>'placedAt')::bigint, 0) desc
    limit greatest(1, least(coalesce(p_limit,15), 50))
  ) q;

  return out_data;
end
$function$;

grant execute on function public.book_my_bets(text,text,integer) to anon, authenticated;
