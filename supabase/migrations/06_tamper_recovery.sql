-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- 06_tamper_recovery.sql — detect when a tampered client recovers (run once in the SQL editor)
--
-- Today an alert never changes once it fires: even after the protected person turns Screen Time
-- back on (or the app comes back to life), the sponsor keeps seeing it forever. This adds a
-- recovered_at flag and clears it on the next live heartbeat — WITHOUT hiding the alert, so the
-- sponsor still sees that it happened and that it's since been fixed, then dismisses it themselves.
--
--   detected_at   = when the tamper happened
--   recovered_at  = when the system saw it fixed (Screen Time back on / app beating again); NULL = still bad
--   resolved_at   = when the user/sponsor cleared it (hidden from the list); NULL = still showing
--
-- Idempotent; safe to run more than once.

begin;

-- 1. New column: when the client was observed to recover (NULL = still in the bad state).
alter table public.tamper_alerts add column if not exists recovered_at timestamptz;

-- 2. record_heartbeat also clears the bad state: any beat means the app is alive (→ 'silence'
--    recovered); an "approved" beat means Screen Time is back on (→ 'auth_lost' recovered). The
--    row stays open (resolved_at null) so the sponsor still sees it, now flagged recovered.
create or replace function public.record_heartbeat(
  p_device_uid text, p_apns_token text, p_auth_status text)
returns void
language plpgsql security definer set search_path = public as $$
declare dev_id uuid;
begin
  insert into public.devices (user_id, device_uid, apns_token, last_heartbeat_at, updated_at)
  values (auth.uid(), p_device_uid, p_apns_token, now(), now())
  on conflict (user_id, device_uid)
    do update set apns_token = coalesce(excluded.apns_token, public.devices.apns_token),
                  last_heartbeat_at = now(), updated_at = now()
  returning id into dev_id;

  insert into public.heartbeats (user_id, device_id, auth_status, sent_at)
  values (auth.uid(), dev_id, p_auth_status, now());

  update public.tamper_alerts
     set recovered_at = now()
   where user_id = auth.uid()
     and resolved_at is null
     and recovered_at is null
     and (kind = 'silence' or (kind = 'auth_lost' and p_auth_status = 'approved'));
end; $$;

-- 3. Manual clear: the user, or an ACTIVE sponsor, marks an alert handled (hides it).
create or replace function public.resolve_tamper_alert(alert_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare a public.tamper_alerts;
begin
  select * into a from public.tamper_alerts where id = alert_id;
  if a.id is null then return; end if;
  if a.user_id <> auth.uid() and not public.is_sponsor_of(a.user_id) then
    raise exception 'not_authorized';
  end if;
  update public.tamper_alerts
     set resolved_at = now()
   where id = alert_id and resolved_at is null;
end; $$;

commit;
