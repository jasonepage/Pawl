-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- ============================================================================
-- Pawl — Phase 2 slice 5: heartbeat / tamper detection
-- Run this in the Supabase SQL editor AFTER schema.sql (additive, idempotent).
-- ----------------------------------------------------------------------------
-- Adds a stable device identity (device_uid = identifierForVendor) so heartbeats
-- aren't tied to having an APNs token; replaces record_heartbeat to match; adds an
-- auth-lost reporter; and schedules silence detection (FR-P2-HEART-002..005, HC-6).
-- ============================================================================

-- 1. Stable per-device identity, independent of the APNs token.
alter table public.devices add column if not exists device_uid text;
alter table public.devices drop constraint if exists devices_user_id_apns_token_key;
create unique index if not exists devices_user_device_uid_key
  on public.devices(user_id, device_uid);

-- 2. Heartbeat ingest, keyed by device_uid. apns_token is stored when present (for
--    later push) but is NOT required — liveness must not depend on push permission.
drop function if exists public.record_heartbeat(text, text);
create or replace function public.record_heartbeat(
  p_device_uid text, p_apns_token text, p_auth_status text)
returns void language plpgsql security definer set search_path = public as $$
declare dev_id uuid;
begin
  insert into public.devices (user_id, device_uid, apns_token, last_heartbeat_at, updated_at)
  values (auth.uid(), p_device_uid, p_apns_token, now(), now())
  on conflict (user_id, device_uid)
    do update set apns_token = coalesce(excluded.apns_token, public.devices.apns_token),
                  last_heartbeat_at = now(),
                  updated_at = now()
  returning id into dev_id;

  insert into public.heartbeats (user_id, device_id, auth_status, sent_at)
  values (auth.uid(), dev_id, p_auth_status, now());
end; $$;

-- 3. Auth-lost reporter: the client calls this on launch when Screen Time authorization
--    is revoked while a sponsor-mode commitment is active (FR-P2-HEART-005). SECURITY
--    DEFINER so it can insert a tamper_alert (clients can't insert directly).
create or replace function public.report_auth_lost()
returns void language plpgsql security definer set search_path = public as $$
begin
  if exists (
        select 1 from public.commitments c
        where c.user_id = auth.uid() and c.status = 'active' and c.sponsor_mode = true)
     and not exists (
        select 1 from public.tamper_alerts t
        where t.user_id = auth.uid() and t.kind = 'auth_lost' and t.resolved_at is null)
  then
    insert into public.tamper_alerts (user_id, kind) values (auth.uid(), 'auth_lost');
  end if;
end; $$;

-- 4. Schedule silence detection hourly (needs the pg_cron extension enabled).
--    Run once; if it says the job already exists, you're already set.
--    To TEST without waiting 24h, run manually with a short window, e.g.:
--      select public.detect_silent_clients(interval '2 minutes');
select cron.schedule('pawl-detect-silence', '0 * * * *',
  $$ select public.detect_silent_clients(); $$);
