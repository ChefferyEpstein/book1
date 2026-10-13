-- Book1 1.8.9 — Connect 4 intelligence stats support
-- Database function version: 32
--
-- Adds richer Connect 4 telemetry to new games:
-- first player, move history and explicit forfeit metadata.

do $patch$
declare
  f text;
  original text;
begin
  select pg_get_functiondef(p.oid) into f
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='book_player_action'
  order by p.oid desc
  limit 1;

  if f is null then
    raise exception 'book_player_action not found';
  end if;

  original := f;

  f := regexp_replace(
    f,
    '''stake'', s1,[[:space:]]+''status'', ''pending'',[[:space:]]+''turn'', null,[[:space:]]+''winner'', null,',
    '''stake'', s1,
      ''status'', ''pending'',
      ''turn'', null,
      ''first'', null,
      ''winner'', null,
      ''history'', ''[]''::jsonb,',
    'g'
  );

  f := regexp_replace(
    f,
    '''status'',''playing'',[[:space:]]+''turn'',opp,[[:space:]]+''startedAt''',
    '''status'',''playing'',
      ''turn'',opp,
      ''first'',opp,
      ''history'',coalesce(g->''history'',''[]''::jsonb),
      ''startedAt''',
    'g'
  );

  f := replace(
    f,
    'g := jsonb_set(g,''{board}'',w);',
    'g := jsonb_set(g,''{board}'',w);
    g := jsonb_set(
      g,
      ''{history}'',
      coalesce(g->''history'',''[]''::jsonb) || jsonb_build_array(jsonb_build_object(
        ''p'',p_name,
        ''col'',s1,
        ''row'',s2,
        ''at'',(extract(epoch from now())*1000)::bigint
      )),
      true
    );'
  );

  f := replace(
    f,
    'g := g || jsonb_build_object(''status'',''done'',''winner'',opp,''turn'',null,''doneAt'',(extract(epoch from now())*1000)::bigint);',
    'g := g || jsonb_build_object(
      ''status'',''done'',
      ''winner'',opp,
      ''turn'',null,
      ''forfeitBy'',p_name,
      ''resultReason'',''forfeit'',
      ''doneAt'',(extract(epoch from now())*1000)::bigint
    );'
  );

  if f = original then
    raise exception 'Connect 4 telemetry patch found nothing to replace';
  end if;

  if position('''first'',opp' in f)=0
     or position('''history'',coalesce(g->''history'',''[]''::jsonb)' in f)=0
     or position('''forfeitBy'',p_name' in f)=0
     or position('''col'',s1' in f)=0 then
    raise exception 'Connect 4 telemetry patch incomplete';
  end if;

  execute f;
end
$patch$;

-- Ensure current stored games have a history field so the client can treat the shape consistently.
update public.book
set data = jsonb_set(
  data,
  '{connect4}',
  coalesce((
    select jsonb_agg(
      case
        when value ? 'history' then value
        else value || jsonb_build_object('history','[]'::jsonb)
      end
      order by ord
    )
    from jsonb_array_elements(coalesce(data->'connect4','[]'::jsonb)) with ordinality x(value,ord)
  ), '[]'::jsonb),
  true
),
updated_at = now()
where id=1;

create or replace function public.book_version()
returns integer
language sql
set search_path = public, extensions
as $function$
  select 32
$function$;
