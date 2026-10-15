-- Protect archived minigame detail from slim-client admin saves and keep rolling Book snapshots.

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
           jsonb_set(p_current || p_incoming, '{connect4}', c4.v, true),
           '{chess}', ch.v, true
         ),
         '{battleships}', bs.v, true
       )
from c4,ch,bs
$function$;

create or replace function public.book_admin_save(p_name text, p_pin text, p_version integer, p_data jsonb)
returns integer
language plpgsql
security definer
set search_path = public, extensions
as $function$
declare
  v int;
  pl jsonb;
  cur jsonb;
  merged jsonb;
begin
  if book_check(p_name, p_pin) is distinct from 'admin' then
    raise exception 'Not the regime';
  end if;

  select version, data into v, cur
  from book
  where id = 1
  for update;

  if v <> p_version then
    raise exception 'STALE';
  end if;

  merged := book_preserve_game_archives(cur, p_data);

  update book
  set data = book_settle_json(merged),
      version = v + 1,
      updated_at = now()
  where id = 1;

  for pl in select * from jsonb_array_elements(merged->'players') loop
    insert into players (name, pin_hash, role, active)
    values (
      pl->>'name',
      extensions.crypt('0000', extensions.gen_salt('bf')),
      coalesce(pl->>'role','player'),
      coalesce((pl->>'active')::boolean, true)
    )
    on conflict (name) do update
      set role = excluded.role,
          active = excluded.active;
  end loop;

  return v + 1;
end
$function$;

create schema if not exists book_internal;
revoke all on schema book_internal from public, anon, authenticated;

create table if not exists book_internal.book_snapshots (
  id bigserial primary key,
  captured_at timestamptz not null default now(),
  version integer not null,
  data jsonb not null
);

alter table book_internal.book_snapshots enable row level security;

create or replace function book_internal.capture_book_snapshot()
returns trigger
language plpgsql
security definer
set search_path = book_internal, public, pg_temp
as $function$
begin
  if new.data is distinct from old.data then
    insert into book_internal.book_snapshots(version, data)
    values (old.version, old.data);

    delete from book_internal.book_snapshots
    where id in (
      select id
      from book_internal.book_snapshots
      order by id desc
      offset 50
    );
  end if;
  return new;
end
$function$;

revoke all on function book_internal.capture_book_snapshot() from public, anon, authenticated;

drop trigger if exists book_capture_snapshot on public.book;
create trigger book_capture_snapshot
before update on public.book
for each row
execute function book_internal.capture_book_snapshot();

insert into book_internal.book_snapshots(version, data)
select b.version, b.data
from public.book b
where b.id = 1
  and not exists (
    select 1 from book_internal.book_snapshots
  );
