-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- 05_tamper_dedupe.sql — one open protection alert per person + kind (run once in the SQL editor)
--
-- Symptom: the Approvals tab showed several identical "App went silent" / "Screen Time was
-- turned off" rows, all with the same timestamp. Those are duplicate OPEN tamper_alerts left
-- over from before the single-active-commitment fix (03_cleanup.sql) — they never resolve, so
-- they linger forever. The app now collapses duplicates in the UI; this removes them at the
-- source and makes new duplicates impossible.
--
-- Idempotent and atomic — safe to run more than once.

begin;

-- ----------------------------------------------------------------------------
-- 1. One-time dedupe: keep the newest OPEN alert per (user, kind); resolve the rest.
--    (detected_at can be identical across the dupes, so id is the tiebreaker.)
-- ----------------------------------------------------------------------------
update public.tamper_alerts t
   set resolved_at = now()
 where t.resolved_at is null
   and t.id <> (
     select t2.id
       from public.tamper_alerts t2
      where t2.user_id = t.user_id
        and t2.kind    = t.kind
        and t2.resolved_at is null
      order by t2.detected_at desc, t2.id
      limit 1
   );

-- ----------------------------------------------------------------------------
-- 2. Hard guarantee: at most one UNRESOLVED alert per (user, kind). A partial unique
--    index, so duplicate open alerts can never be created again — regardless of how many
--    times detection runs or how many active commitments a user has.
-- ----------------------------------------------------------------------------
create unique index if not exists tamper_alerts_one_open_per_kind
  on public.tamper_alerts (user_id, kind)
  where resolved_at is null;

-- ----------------------------------------------------------------------------
-- 3. Make the inserters tolerate the guard. Both already check for an open alert first;
--    ON CONFLICT DO NOTHING is belt-and-suspenders so the unique index can never raise
--    (e.g. on a race) and break a launch or the hourly cron.
-- ----------------------------------------------------------------------------
create or replace function public.report_auth_lost()
returns void
language plpgsql security definer set search_path = public as $$
begin
  if exists (
        select 1 from public.commitments c
        where c.user_id = auth.uid() and c.status = 'active' and c.sponsor_mode = true)
     and not exists (
        select 1 from public.tamper_alerts t
        where t.user_id = auth.uid() and t.kind = 'auth_lost' and t.resolved_at is null)
  then
    insert into public.tamper_alerts (user_id, kind)
    values (auth.uid(), 'auth_lost')
    on conflict (user_id, kind) where resolved_at is null do nothing;
  end if;
end; $$;

create or replace function public.detect_silent_clients(threshold interval default interval '24 hours')
returns setof public.tamper_alerts
language plpgsql security definer set search_path = public as $$
begin
  return query
  insert into public.tamper_alerts (user_id, kind, detected_at)
  select distinct c.user_id, 'silence', now()      -- distinct: dup active commitments → one alert
  from public.commitments c
  where c.status = 'active' and c.sponsor_mode = true
    and (
      select coalesce(max(d.last_heartbeat_at), 'epoch')
      from public.devices d where d.user_id = c.user_id
    ) < now() - threshold
    and not exists (
      select 1 from public.tamper_alerts t
      where t.user_id = c.user_id and t.kind = 'silence' and t.resolved_at is null
    )
  on conflict (user_id, kind) where resolved_at is null do nothing
  returning *;
end; $$;

commit;

-- ----------------------------------------------------------------------------
-- Verify (optional) — should return ZERO rows after running:
--   select user_id, kind, count(*)
--     from public.tamper_alerts
--    where resolved_at is null
--    group by user_id, kind
--   having count(*) > 1;
-- ----------------------------------------------------------------------------
