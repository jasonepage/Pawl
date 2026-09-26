-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- ============================================================================
-- 10_repair_audit_2026-08-16.sql
-- ----------------------------------------------------------------------------
-- Follow-up to the full forensic audit of project bvixxdlmjeulxrefmqjx (2026-08-16).
--
-- IMPORTANT CONTEXT: the audit found NO damage from foreign SQL. Every table,
-- policy, function, trigger, index and constraint from schema.sql + migrations
-- 01-09 is present and correct, and the DDL history contains nothing but Pawl's
-- own statements. This file fixes THREE PRE-EXISTING issues that the audit
-- surfaced along the way. None of them were caused by the bad paste.
--
-- Run in the Supabase SQL editor. Idempotent; safe to run more than once.
-- Sections 1-3 are recommended. Section 4 is optional cleanup.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 1. FIX: profiles_counterpart_read — second clause has never worked.
--
-- schema.sql:213 wrote the subquery as:
--     ... exists (select 1 from public.sponsor_links sl where sl.sponsor_id = id ...)
-- The unqualified `id` binds to the INNER relation (sponsor_links.id), not to the
-- outer profiles.id — Postgres resolves the innermost scope first. The live policy
-- is stored as `sl.sponsor_id = sl.id`, a comparison between a sponsor's user id
-- and a link's primary key, which is effectively never true.
--
-- EFFECT: the sponsor->user read direction works (via is_sponsor_of), but the
-- user->sponsor direction does not. A protected person cannot read their own
-- sponsor's profile row, so any sponsor display_name shown on the protected side
-- comes back empty. Not currently biting anyone (all 5 sponsor_links are revoked),
-- but it will the moment a real sponsor pair is set up.
--
-- FIX: qualify the outer column explicitly.
-- ----------------------------------------------------------------------------
drop policy if exists profiles_counterpart_read on public.profiles;
create policy profiles_counterpart_read on public.profiles
  for select using (
    public.is_sponsor_of(profiles.id)                 -- I sponsor this profile
    or exists (                                       -- or this profile sponsors me
      select 1 from public.sponsor_links sl
      where sl.sponsor_id = profiles.id
        and sl.user_id    = auth.uid()
        and sl.status     = 'active'
    )
  );

-- ----------------------------------------------------------------------------
-- 2. FIX: detect_silent_clients is callable by any client holding the anon key.
--
-- The anon key ships inside the iOS app, so it is effectively public. Postgres
-- grants EXECUTE on new functions to PUBLIC by default, and unlike every other
-- Pawl RPC, detect_silent_clients does NOT scope its work to auth.uid() — it
-- sweeps EVERY sponsor-mode user. A caller can pass their own threshold:
--
--     POST /rest/v1/rpc/detect_silent_clients  {"threshold": "00:00:00"}
--
-- ...which inserts a 'silence' tamper_alert for every sponsor-mode user in the
-- project and, on the next hourly cron, pushes every one of their sponsors.
-- That is a false-alarm amplifier aimed at exactly the notification users are
-- meant to trust. It is the one genuine security finding in the audit.
--
-- The hourly pg_cron job and the detect-silence Edge Function both run as the
-- service role, which bypasses these grants — so revoking costs nothing.
--
-- NOTE: this does NOT fix the parallel issue in application code, where
-- HeartbeatService.beat() invokes the detect-silence Edge Function (which runs
-- the same global sweep with the service-role key). That needs a Swift/TS change:
-- replace the client call with a narrow function scoped to auth.uid(), and leave
-- the fleet-wide sweep to pg_cron only. See the status doc, "Security" section.
-- ----------------------------------------------------------------------------
revoke execute on function public.detect_silent_clients(interval) from public, anon, authenticated;
grant  execute on function public.detect_silent_clients(interval) to service_role;

-- Trigger functions are not meant to be RPCs at all; this one is exposed only
-- because of the same default grant. Calling it errors out harmlessly, but there
-- is no reason to leave it on the public API surface.
revoke execute on function public.enforce_single_active_commitment() from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 3. FIX: column default drift on commitments.grace_seconds.
--
-- Repo schema.sql:53 says `default 1800` (grace default was raised to 30 min in
-- Phase 2). The live column still carries the original `default 900` — the repo
-- file was edited after the project was created and the ALTER never ran.
--
-- Low impact: the client writes grace_seconds explicitly on every insert, so no
-- existing row is wrong. This just makes the live schema match the file, so the
-- next person to diff them doesn't chase a phantom.
-- ----------------------------------------------------------------------------
alter table public.commitments alter column grace_seconds set default 1800;

commit;


-- ============================================================================
-- 4. OPTIONAL CLEANUP — review before running. Each block is independent.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 4a. Expire stale pending unlock_requests.
--
-- unlock_requests.expires_at defaults to now() + 60 minutes and decide_unlock()
-- refuses expired rows — but nothing ever writes status = 'expired'. Today this
-- is theoretical (0 stale rows right now), but as soon as sponsors are live a
-- request that nobody answers sits 'pending' forever, clutters the sponsor's
-- Approvals queue, and raises a raw `request_expired` Postgres exception if the
-- sponsor eventually taps Approve.
--
-- This adds an hourly sweep alongside the existing pawl-detect-silence-push job.
-- ----------------------------------------------------------------------------
-- create or replace function public.expire_stale_unlock_requests()
-- returns integer
-- language plpgsql security definer set search_path = public as $$
-- declare n integer;
-- begin
--   update public.unlock_requests
--      set status = 'expired', outcome = 'expired'
--    where status = 'pending' and expires_at <= now();
--   get diagnostics n = row_count;
--   return n;
-- end; $$;
--
-- revoke execute on function public.expire_stale_unlock_requests() from public, anon, authenticated;
-- grant  execute on function public.expire_stale_unlock_requests() to service_role;
--
-- select cron.schedule('pawl-expire-unlock-requests', '5 * * * *',
--   $$ select public.expire_stale_unlock_requests(); $$);

-- ----------------------------------------------------------------------------
-- 4b. Clear the two lingering June tamper alerts.
--
-- Both are kind='auth_lost' for user 5c3ddd14, detected 2026-06-27, and BOTH
-- already have recovered_at set — the system saw Screen Time come back on within
-- ~25 min and ~3 min respectively. They are working exactly as designed (07's
-- partial unique index only counts unresolved AND unrecovered rows, so they are
-- not suppressing new alerts). They just still render in the Approvals tab
-- because nobody tapped dismiss. Almost certainly your own June test runs.
--
-- Uncomment to dismiss them.
-- ----------------------------------------------------------------------------
-- update public.tamper_alerts
--    set resolved_at = now()
--  where resolved_at is null and recovered_at is not null;

-- ----------------------------------------------------------------------------
-- 4c. Blocklist size — informational, no SQL change proposed. READ THIS THOUGH.
--
-- Data is healthy: 4,000 rows (3,833 hagezi + 167 pawl-curated), all loaded
-- 2026-06-26, zero junk, no '404' poisoning from the old dead-ingest bug.
-- HANDOFF.md still says 1,500 — the doc is stale, the table is fine.
--
-- Verified against BlocklistService.swift (not assumed): maxDomains = 4000, and
-- fetchAndStore() pages through in 1,000-row ranges, so all 4,000 are retrieved.
-- normalizedMerge seeds the set with GamblingBlocklist.seedDomains (~35) FIRST
-- and then breaks once the set hits 4,000 — so roughly the last ~35 fetched
-- domains are silently dropped, and which ones varies per launch because the
-- query has no ORDER BY. Minor (35/4000), but it means the enforced list is not
-- byte-identical across launches. A one-line `.order("domain")` makes it
-- deterministic; raising maxDomains to 4100 makes the truncation go away.
--
-- The bigger open question is whether 4,000 domains is past the point where
-- Screen Time's webContent filter degrades. HANDOFF §8 flags Screen Time as
-- slowing "in the hundreds to low thousands", and that has never been measured
-- on a real device. Worth an on-device timing pass before shipping 2.0 — if it
-- does degrade, trim to a ranked top-N rather than raising the cap.
-- ----------------------------------------------------------------------------
-- select source, count(*) from public.blocklist_domains group by source;
