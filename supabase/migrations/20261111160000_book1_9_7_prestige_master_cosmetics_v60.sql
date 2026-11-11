do $migration$
declare
 v_definition text;
 v_start integer;
 v_end integer;
begin
 v_definition := pg_get_functiondef('public.book_player_action(text,text,jsonb)'::regprocedure);
 v_start := position('elsif t = ''profile'' then' in v_definition);
 v_end := position('elsif t = ''ping'' then' in v_definition);
 if v_start=0 or v_end=0 or v_end<=v_start then raise exception 'Could not locate profile/ping branches; migration stopped.'; end if;
 execute left(v_definition,v_start-1) || $replacement$  elsif t = 'profile' then
    if coalesce(p_action->>'tag','') !~ '^[A-Za-z0-9]{0,5}$' then raise exception 'Tag: up to 5 letters or numbers'; end if;
    if length((p_action->'emblem')::text) > 6000 or jsonb_array_length(coalesce(p_action->'emblem'->'layers','[]'::jsonb)) > 8 then raise exception 'Emblem too big'; end if;
    if coalesce(p_action->>'nameColor','#FFFFFF') !~ '^#[0-9A-Fa-f]{6}$' then raise exception 'Choose a valid name colour.'; end if;
    if coalesce((p_action->>'prestigeMasterTheme')::boolean,false)
       and coalesce((d->'progression'->p_name->>'prestige')::int,0) < 10 then
      raise exception 'Prestige Master unlocks at Prestige 10.';
    end if;
    d := d || jsonb_build_object('profiles', coalesce(d->'profiles', '{}'::jsonb));
    d := jsonb_set(d, array['profiles', p_name], jsonb_build_object(
      'tag', upper(coalesce(p_action->>'tag','')),
      'emblem', p_action->'emblem',
      'nameColor', upper(coalesce(p_action->>'nameColor','#FFFFFF')),
      'prestigeMasterTheme', coalesce((p_action->>'prestigeMasterTheme')::boolean,false)
    ));
    d := jsonb_set(d, '{log}', (d->'log') || to_jsonb(stamp || ' ' || p_name || ' updated their identity'));
  elsif t = 'ping' then$replacement$ || substr(v_definition,v_end+length('elsif t = ''ping'' then'));
end
$migration$;
create or replace function public.book_version()
returns integer language sql set search_path to 'public','extensions'
as $function$ select 60 $function$;