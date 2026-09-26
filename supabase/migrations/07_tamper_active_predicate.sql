-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- 07_tamper_active_predicate.sql — let a NEW tamper re-alert after recovery (run once, after 05 & 06)
--
-- Problem: once an alert fired, the sponsor stopped being notified about the NEXT tamper of the
-- same kind. The "is there already an open alert?" check counted ANY unresolved row — including
-- ones that already recovered (recovered_at set) or that the sponsor simply hadn't cleared. So a
-- stale "Screen Time was turned off" suppressed the next real one.
--
-- Fix: an alert is ACTIVE (and only an ACTIVE one blocks a duplicate) while it is BOTH unresolved
-- AND not recovered. A recovered or cleared alert never suppresses a fresh event again.
--
-- Idempotent; safe to run more than once.

begin;

-- 1. Uniqueness applies only to truly-active alerts (unresolved AND unrecovered).
drop index if exists public.tamper_alerts_one_open_per_kind;
create unique index if not exists tamper_alerts_one_active_per_kind
  on public.tamper_alerts (user_id, kind)
  where resolved_at is null and recovered_at is null;

-- 2. report_auth_lost: create a new alert unless an ACTIVE one already exists.
create or replace function public.report_auth_lost()
returns void
language plpgsql security definer set search_path = public as $$
begin
  if exists (
        select 1 from public.commitments c
        where c.user_id = auth.uid() and c.status = 'active' and c.sponsor_mode = true)
     and not exists (
        select 1 from public.tamper_alerts t
        where t.user_id = auth.uid() and t.kind = 'auth_lost'
          and t.resolved_at is null and t.recovered_at is null)
  then
    insert into public.tamper_alerts (user_id, kind)
    values (auth.uid(), 'auth_lost')
    on conflict (user_id, kind) where resolved_at is null and recovered_at is null do nothing;
  end if;
end; $$;

-- 3. detect_silent_clients: same — only an ACTIVE silence alert blocks a new one.
create or replace function public.detect_silent_clients(threshold interval default interval '24 hours')
returns setof public.tamper_alerts
language plpgsql security definer set search_path = public as $$
begin
  return query
  insert into public.tamper_alerts (user_id, kind, detected_at)
  select distinct c.user_id, 'silence', now()
  from public.commitments c
  where c.status = 'active' and c.sponsor_mode = true
    and (
      select coalesce(max(d.last_heartbeat_at), 'epoch')
      from public.devices d where d.user_id = c.user_id
    ) < now() - threshold
    and not exists (
      select 1 from public.tamper_alerts t
      where t.user_id = c.user_id and t.kind = 'silence'
        and t.resolved_at is null and t.recovered_at is null
    )
  on conflict (user_id, kind) where resolved_at is null and recovered_at is null do nothing
  returning *;
end; $$;

commit;

-- ----------------------------------------------------------------------------
-- Optional: to TEST the new behavior immediately, clear the stale open alerts so the next
-- turn-off fires a fresh one (this resolves everything currently showing):
--   update public.tamper_alerts set resolved_at = now() where resolved_at is null;
-- ----------------------------------------------------------------------------
