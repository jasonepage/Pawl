-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- 11_block_signed_out_rpc.sql  (applied 2026-09-26)
--
-- Why: every SECURITY DEFINER function in the public schema was executable by the
-- `anon` role, which is anyone holding the public anon key that ships inside the app.
-- For most of them that was harmless, because auth.uid() is null for anon and the
-- function then touches nothing. resolve_tamper_alert was the exception:
--
--     if a.user_id <> auth.uid() and not public.is_sponsor_of(a.user_id) then
--
-- With auth.uid() null, the first test is NULL, NULL AND TRUE is NULL, and plpgsql
-- treats a NULL condition as false. So the permission check was skipped and a signed
-- out caller holding an alert's id could mark it resolved. Alert ids are random UUIDs
-- that anon cannot read, so this was hard to use in practice, but it was a real hole.
--
-- Fix, two layers:
--   1. resolve_tamper_alert refuses a null caller outright.
--   2. The seven client RPCs are no longer executable by anon or PUBLIC; only
--      `authenticated` (and service_role) can call them.
--
-- is_sponsor_of stays executable by anon on purpose. RLS policies that apply to
-- every role call it, so revoking it would turn a signed out table read into an
-- error instead of an empty result. For anon it can only ever return false.

create or replace function public.resolve_tamper_alert(alert_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare a public.tamper_alerts;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  select * into a from public.tamper_alerts where id = alert_id;
  if a.id is null then return; end if;
  if a.user_id is distinct from auth.uid() and not public.is_sponsor_of(a.user_id) then
    raise exception 'not_authorized';
  end if;
  update public.tamper_alerts
     set resolved_at = now()
   where id = alert_id and resolved_at is null;
end; $function$;

do $$
declare f text;
begin
  foreach f in array array[
    'public.decide_unlock(uuid, boolean)',
    'public.record_heartbeat(text, text, text)',
    'public.redeem_invite(text)',
    'public.report_auth_lost()',
    'public.resolve_tamper_alert(uuid)',
    'public.revoke_sponsorship(uuid)',
    'public.set_hard_lock(boolean)'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated, service_role', f);
  end loop;
end $$;
