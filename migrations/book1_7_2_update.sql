-- Book1 1.7.2 database update (v26)
-- Safe to re-run.
--
-- Changes:
--   1) Chip purchase request cap: 5,000 -> 500,000 chips
--   2) Live chip price: £0.20 per 10,000 chips (= £1 per 50,000)
--   3) Database function version: 25 -> 26
--
-- The regime approve/deny roll-call bug is a client routing fix and does not
-- require a database function change.

begin;

do $$
declare
  f text;
  old_guard text := 'if s1 is null or s1 < 1 or s1 > 5000 then raise exception ''Ask for between 1 and 5,000 chips.''; end if;';
  new_guard text := 'if s1 is null or s1 < 1 or s1 > 500000 then raise exception ''Ask for between 1 and 500,000 chips.''; end if;';
begin
  select pg_get_functiondef(
    'public.book_player_action(text,text,jsonb)'::regprocedure
  )
  into f;

  if position(new_guard in f) > 0 then
    -- Already upgraded.
    null;
  elsif position(old_guard in f) > 0 then
    f := replace(f, old_guard, new_guard);
    execute f;
  else
    raise exception
      'Book1 1.7.2 migration stopped: expected 1.7.1 requestChips guard was not found. No changes committed.';
  end if;
end
$$;

-- £0.20 per 10,000 chips = £1 per 50,000 chips.
-- Only touch the book row if the value actually needs changing.
update public.book
set
  data = jsonb_set(
    data,
    '{payouts,chipPrice}',
    to_jsonb(0.20::numeric),
    true
  ),
  version = version + 1,
  updated_at = now()
where id = 1
  and coalesce((data #>> '{payouts,chipPrice}')::numeric, -1) is distinct from 0.20::numeric;

create or replace function public.book_version()
returns integer
language sql
as $function$
  select 26
$function$;

commit;

-- Verification: should show 26, 0.20, true.
select
  public.book_version() as database_function_version,
  data #>> '{payouts,chipPrice}' as chip_price_per_10000,
  position(
    's1 > 500000' in
    pg_get_functiondef('public.book_player_action(text,text,jsonb)'::regprocedure)
  ) > 0 as chip_request_cap_updated
from public.book
where id = 1;
