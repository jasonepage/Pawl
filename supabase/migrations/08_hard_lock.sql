-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- 08_hard_lock.sql — server-side hard lock + breach escalation (run once, after 05–07)
--
-- The hard lock = a sponsor-set device Screen Time passcode (docs/11). iOS gives NO API to set,
-- read, or even detect that passcode, so Pawl can't verify it — it records the sponsor's
-- ATTESTATION and then monitors. This migration moves the attestation from a local-only flag to
-- the commitment (so the sponsor's app + the server can act on it), and flags any tamper alert
-- that fires on a hard-locked commitment as a BREACH — because if the passcode is really set, the
-- user can't disable Screen Time or delete the app, so such an alert means the lock failed
-- (FR-P3-HARD-004/005/006).
--
-- Idempotent; safe to run more than once.

begin;

-- 1. Attestation lives on the commitment (linked sponsor can already read it via commitments_sponsor_read).
alter table public.commitments
  add column if not exists hard_lock_active      boolean not null default false,
  add column if not exists hard_lock_attested_at timestamptz,
  add column if not exists hard_lock_attested_by uuid;

-- 2. Each alert records whether the commitment was hard-locked when it fired (→ breach).
alter table public.tamper_alerts
  add column if not exists hard_locked boolean not null default false;

-- 3. set_hard_lock: the user (sponsor present, in person) records / clears the attestation on their
--    active commitment. It is an ATTESTATION, not a Pawl-verified fact (iOS can't confirm it).
create or replace function public.set_hard_lock(p_active boolean)
returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.commitments
     set hard_lock_active      = p_active,
         hard_lock_attested_at = case when p_active then now()        else hard_lock_attested_at end,
         hard_lock_attested_by = case when p_active then auth.uid()   else hard_lock_attested_by end,
         updated_at            = now()
   where user_id = auth.uid() and status = 'active';
end; $$;

-- 4. report_auth_lost: create a new alert unless an ACTIVE one exists; stamp hard_locked.
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
    insert into public.tamper_alerts (user_id, kind, hard_locked)
    values (auth.uid(), 'auth_lost',
            coalesce((select c.hard_lock_active from public.commitments c
                      where c.user_id = auth.uid() and c.status = 'active' limit 1), false))
    on conflict (user_id, kind) where resolved_at is null and recovered_at is null do nothing;
  end if;
end; $$;

-- 5. detect_silent_clients: stamp hard_locked from the (one) active commitment per user.
create or replace function public.detect_silent_clients(threshold interval default interval '24 hours')
returns setof public.tamper_alerts
language plpgsql security definer set search_path = public as $$
begin
  return query
  insert into public.tamper_alerts (user_id, kind, detected_at, hard_locked)
  select distinct c.user_id, 'silence', now(), c.hard_lock_active
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
