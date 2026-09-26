-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- ============================================================================
-- Pawl — Phase 2 Supabase schema (Postgres + RLS + RPCs)
-- ----------------------------------------------------------------------------
-- Run this in the Supabase SQL editor on a fresh project (one paste, run once).
-- Canonical source of truth for account/commitment/accountability data
-- (Decision D-P2-1). Traces SRS §6.1 and SDS §3.3. Least-privilege RLS: sponsors
-- never get direct write grants on a user's rows — they act via SECURITY DEFINER
-- RPCs (redeem_invite, decide_unlock).
--
-- Re-runnable: uses IF NOT EXISTS / CREATE OR REPLACE and drops policies first.
-- ============================================================================

create extension if not exists pgcrypto;   -- gen_random_uuid()
-- NOTE: enable `pg_cron` from Dashboard → Database → Extensions to schedule
-- detect_silent_clients() hourly (see §8 of docs/09_Supabase_APNs_Setup.md).

-- ----------------------------------------------------------------------------
-- 1. profiles  (1:1 with auth.users)
-- ----------------------------------------------------------------------------
create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 2. sponsor_links  (user invites a sponsor via a single-use, expiring code)
-- ----------------------------------------------------------------------------
create table if not exists public.sponsor_links (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,   -- the protected person
  sponsor_id  uuid references auth.users(id) on delete set null,           -- null until redeemed
  invite_code text not null unique,
  status      text not null default 'pending' check (status in ('pending','active','revoked')),
  expires_at  timestamptz not null default (now() + interval '7 days'),
  accepted_at timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists sponsor_links_user_idx    on public.sponsor_links(user_id);
create index if not exists sponsor_links_sponsor_idx on public.sponsor_links(sponsor_id);

-- ----------------------------------------------------------------------------
-- 3. commitments  (mirror of domain Commitment + sponsor_mode)
-- ----------------------------------------------------------------------------
create table if not exists public.commitments (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references auth.users(id) on delete cascade,
  status             text not null default 'active' check (status in ('active','inactive')),
  started_at         timestamptz not null,
  cooling_off_seconds integer not null default 900 check (cooling_off_seconds >= 900),  -- FR-UNLOCK-004 floor
  grace_seconds      integer not null default 1800,
  sponsor_mode       boolean not null default false,
  hard_lock_active   boolean not null default false,    -- sponsor-set Screen Time passcode attested (docs/11; 08_hard_lock.sql)
  hard_lock_attested_at timestamptz,
  hard_lock_attested_by uuid,
  updated_at         timestamptz not null default now()
);
create index if not exists commitments_user_idx on public.commitments(user_id);

-- ----------------------------------------------------------------------------
-- 4. block_sets  (opaque selection tokens — HC-1; owner-only)
-- ----------------------------------------------------------------------------
create table if not exists public.block_sets (
  id                   uuid primary key default gen_random_uuid(),
  commitment_id        uuid not null references public.commitments(id) on delete cascade,
  user_id              uuid not null references auth.users(id) on delete cascade,
  selection_token_data bytea,                  -- archived FamilyActivitySelection (never resolved)
  web_domains          text[] not null default '{}',
  updated_at           timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 5. unlock_requests  (decision recorded inline; sponsor decides via RPC)
-- ----------------------------------------------------------------------------
create table if not exists public.unlock_requests (
  id                  uuid primary key default gen_random_uuid(),
  commitment_id       uuid not null references public.commitments(id) on delete cascade,
  user_id             uuid not null references auth.users(id) on delete cascade,
  requested_at        timestamptz not null default now(),
  status              text not null default 'pending'
                        check (status in ('pending','approved','denied','expired','cancelled')),
  decided_by          uuid references auth.users(id) on delete set null,  -- SET NULL so deleting a sponsor's account can't FK-fail (see 09)
  decided_at          timestamptz,
  cooling_off_ends_at timestamptz,
  grace_ends_at       timestamptz,
  outcome             text default 'pending',
  expires_at          timestamptz not null default (now() + interval '60 minutes'),  -- FR-P2-SPON-005
  created_at          timestamptz not null default now()
);
create index if not exists unlock_requests_user_idx   on public.unlock_requests(user_id);
create index if not exists unlock_requests_status_idx on public.unlock_requests(status);

-- ----------------------------------------------------------------------------
-- 6. devices  (APNs token + last heartbeat per device; owner-only)
-- ----------------------------------------------------------------------------
create table if not exists public.devices (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users(id) on delete cascade,
  device_uid        text,                       -- identifierForVendor (stable device identity)
  apns_token        text,                       -- stored when available; not required for liveness
  platform          text not null default 'ios',
  last_heartbeat_at timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (user_id, device_uid)
);
create index if not exists devices_user_idx on public.devices(user_id);

-- ----------------------------------------------------------------------------
-- 7. heartbeats  (append log; owner-insert only; detection by service role)
-- ----------------------------------------------------------------------------
create table if not exists public.heartbeats (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  device_id   uuid references public.devices(id) on delete cascade,
  auth_status text,                            -- 'approved' / 'denied' / 'notDetermined'
  sent_at     timestamptz not null default now()
);
create index if not exists heartbeats_user_idx on public.heartbeats(user_id, sent_at desc);

-- ----------------------------------------------------------------------------
-- 8. tamper_alerts  (server-inserted; user + linked sponsor can read)
-- ----------------------------------------------------------------------------
create table if not exists public.tamper_alerts (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  kind        text not null check (kind in ('silence','auth_lost')),
  detected_at timestamptz not null default now(),
  resolved_at timestamptz,
  recovered_at timestamptz,                      -- system saw the client recover; still shown (see 06_tamper_recovery.sql)
  hard_locked boolean not null default false,    -- commitment was hard-locked when this fired → breach (08_hard_lock.sql)
  notified    boolean not null default false
);
create index if not exists tamper_alerts_user_idx on public.tamper_alerts(user_id);
-- At most one ACTIVE alert per (user, kind) — active = unresolved AND not yet recovered, so a
-- recovered/cleared alert never suppresses a genuinely new tamper (see 05/06/07 migrations).
create unique index if not exists tamper_alerts_one_active_per_kind
  on public.tamper_alerts (user_id, kind) where resolved_at is null and recovered_at is null;

-- ----------------------------------------------------------------------------
-- 9. webauthn_credentials  (optional server-side verification, FR-P2-WAUTH-*)
-- ----------------------------------------------------------------------------
create table if not exists public.webauthn_credentials (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  credential_id bytea not null,
  public_key    bytea not null,
  sign_count    bigint not null default 0,
  created_at    timestamptz not null default now(),
  unique (user_id, credential_id)
);

-- ----------------------------------------------------------------------------
-- 10. relapse_events / urge_events  (private journal — OWNER-ONLY, never sponsor)
-- ----------------------------------------------------------------------------
create table if not exists public.relapse_events (
  id            uuid primary key default gen_random_uuid(),
  commitment_id uuid not null references public.commitments(id) on delete cascade,
  user_id       uuid not null references auth.users(id) on delete cascade,
  occurred_at   timestamptz not null default now(),
  note          text,
  amount        numeric
);
create table if not exists public.urge_events (
  id            uuid primary key default gen_random_uuid(),
  commitment_id uuid not null references public.commitments(id) on delete cascade,
  user_id       uuid not null references auth.users(id) on delete cascade,
  occurred_at   timestamptz not null default now(),
  intensity     integer,
  trigger       text,
  note          text
);

-- ============================================================================
-- Helper: is the caller an ACTIVE sponsor of :target ?  (bypasses RLS safely)
-- ============================================================================
create or replace function public.is_sponsor_of(target uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.sponsor_links sl
    where sl.user_id = target
      and sl.sponsor_id = auth.uid()
      and sl.status = 'active'
  );
$$;

-- ============================================================================
-- Row-Level Security  (FR-P2-AUTH-004)
-- ============================================================================
alter table public.profiles            enable row level security;
alter table public.sponsor_links       enable row level security;
alter table public.commitments         enable row level security;
alter table public.block_sets          enable row level security;
alter table public.unlock_requests     enable row level security;
alter table public.devices             enable row level security;
alter table public.heartbeats          enable row level security;
alter table public.tamper_alerts       enable row level security;
alter table public.webauthn_credentials enable row level security;
alter table public.relapse_events      enable row level security;
alter table public.urge_events         enable row level security;

-- profiles: self full; linked counterpart may read display name
drop policy if exists profiles_self on public.profiles;
create policy profiles_self on public.profiles
  for all using (id = auth.uid()) with check (id = auth.uid());
drop policy if exists profiles_counterpart_read on public.profiles;
create policy profiles_counterpart_read on public.profiles
  for select using (
    public.is_sponsor_of(id)                                    -- I sponsor this profile
    or exists (select 1 from public.sponsor_links sl            -- or this profile sponsors me
               where sl.sponsor_id = id and sl.user_id = auth.uid() and sl.status = 'active')
  );

-- sponsor_links: the user owns their links; the sponsor may read links pointing at them
drop policy if exists sponsor_links_owner on public.sponsor_links;
create policy sponsor_links_owner on public.sponsor_links
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists sponsor_links_sponsor_read on public.sponsor_links;
create policy sponsor_links_sponsor_read on public.sponsor_links
  for select using (sponsor_id = auth.uid());
-- (redemption is via redeem_invite() RPC — no direct UPDATE grant to strangers)

-- commitments: self full; linked sponsor read-only
drop policy if exists commitments_self on public.commitments;
create policy commitments_self on public.commitments
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists commitments_sponsor_read on public.commitments;
create policy commitments_sponsor_read on public.commitments
  for select using (public.is_sponsor_of(user_id));

-- block_sets: owner only (HC-1 opaque tokens; sponsor never reads)
drop policy if exists block_sets_self on public.block_sets;
create policy block_sets_self on public.block_sets
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- unlock_requests: self full; linked sponsor read-only (decision via decide_unlock RPC)
drop policy if exists unlock_requests_self on public.unlock_requests;
create policy unlock_requests_self on public.unlock_requests
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists unlock_requests_sponsor_read on public.unlock_requests;
create policy unlock_requests_sponsor_read on public.unlock_requests
  for select using (public.is_sponsor_of(user_id));

-- devices / heartbeats / webauthn_credentials: owner only
drop policy if exists devices_self on public.devices;
create policy devices_self on public.devices
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists heartbeats_self on public.heartbeats;
create policy heartbeats_self on public.heartbeats
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists webauthn_self on public.webauthn_credentials;
create policy webauthn_self on public.webauthn_credentials
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- tamper_alerts: user + linked sponsor read; inserts come from service role (cron fn)
drop policy if exists tamper_alerts_read on public.tamper_alerts;
create policy tamper_alerts_read on public.tamper_alerts
  for select using (user_id = auth.uid() or public.is_sponsor_of(user_id));

-- relapse / urge: OWNER ONLY — no sponsor read policy (FR-P2-PRIV-001)
drop policy if exists relapse_self on public.relapse_events;
create policy relapse_self on public.relapse_events
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists urge_self on public.urge_events;
create policy urge_self on public.urge_events
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ============================================================================
-- RPCs  (least privilege — sponsors mutate only through these)
-- ============================================================================

-- redeem_invite: a signed-in sponsor redeems a pending, unexpired code (FR-P2-LINK-002)
create or replace function public.redeem_invite(code text)
returns public.sponsor_links
language plpgsql security definer set search_path = public as $$
declare link public.sponsor_links;
begin
  update public.sponsor_links
     set sponsor_id = auth.uid(), status = 'active', accepted_at = now(), updated_at = now()
   where invite_code = code
     and status = 'pending'
     and sponsor_id is null
     and expires_at > now()
     and user_id <> auth.uid()                    -- can't sponsor yourself
  returning * into link;

  if link.id is null then
    raise exception 'invalid_or_expired_invite';
  end if;

  -- flip the user's active commitment into sponsor mode (FR-P2-LINK-005)
  update public.commitments
     set sponsor_mode = true, updated_at = now()
   where user_id = link.user_id and status = 'active';

  return link;
end; $$;

-- decide_unlock: the active sponsor approves/denies a pending request (FR-P2-SPON-003/004)
create or replace function public.decide_unlock(request_id uuid, approved boolean)
returns public.unlock_requests
language plpgsql security definer set search_path = public as $$
declare req public.unlock_requests;
begin
  select * into req from public.unlock_requests where id = request_id;
  if req.id is null then raise exception 'request_not_found'; end if;
  if not public.is_sponsor_of(req.user_id) then raise exception 'not_authorized'; end if;
  if req.status <> 'pending' then raise exception 'already_decided'; end if;
  if req.expires_at <= now() then raise exception 'request_expired'; end if;

  update public.unlock_requests
     set status = case when approved then 'approved' else 'denied' end,
         decided_by = auth.uid(),
         decided_at = now()
   where id = request_id
  returning * into req;

  return req;   -- the decide-unlock Edge Function APNs-pushes the user afterward
end; $$;

-- record_heartbeat: client upserts its device (keyed by device_uid) + appends a beat
-- (FR-P2-HEART-002). apns_token is stored when present but not required for liveness.
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

  -- recovery: a live/authorized beat flags matching open alerts as recovered (kept visible).
  update public.tamper_alerts
     set recovered_at = now()
   where user_id = auth.uid()
     and resolved_at is null
     and recovered_at is null
     and (kind = 'silence' or (kind = 'auth_lost' and p_auth_status = 'approved'));
end; $$;

-- report_auth_lost: client calls on launch if Screen Time authorization is revoked while a
-- sponsor-mode commitment is active (FR-P2-HEART-005). SECURITY DEFINER to insert the alert.
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

-- detect_silent_clients: scheduled (hourly). Flags sponsor-mode users whose newest
-- device heartbeat is older than the threshold and that have no open silence alert
-- (FR-P2-HEART-003/004, HC-6). The detect-silence Edge Function calls this, then
-- APNs-pushes the sponsor for each returned row.
create or replace function public.detect_silent_clients(threshold interval default interval '24 hours')
returns setof public.tamper_alerts
language plpgsql security definer set search_path = public as $$
begin
  return query
  insert into public.tamper_alerts (user_id, kind, detected_at, hard_locked)
  select distinct c.user_id, 'silence', now(), c.hard_lock_active   -- distinct: one active commitment per user
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

-- resolve_tamper_alert: the user, or an ACTIVE sponsor, marks an alert handled (hides it from
-- the Approvals list). record_heartbeat sets recovered_at to auto-flag recovery while keeping the
-- alert visible; this is the explicit dismiss. See 06_tamper_recovery.sql.
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

-- set_hard_lock: the user (with their sponsor present, in person) records or clears the hard-lock
-- attestation on their active commitment. An ATTESTATION, not a Pawl-verified fact — iOS exposes no
-- API to set/read the Screen Time passcode. See docs/11_Phase3_Passcode.md and 08_hard_lock.sql.
create or replace function public.set_hard_lock(p_active boolean)
returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.commitments
     set hard_lock_active      = p_active,
         hard_lock_attested_at = case when p_active then now()      else hard_lock_attested_at end,
         hard_lock_attested_by = case when p_active then auth.uid() else hard_lock_attested_by end,
         updated_at            = now()
   where user_id = auth.uid() and status = 'active';
end; $$;

-- ============================================================================
-- Done. Next: deploy Edge Functions (unlock-request-notify, decide-unlock,
-- detect-silence) and schedule detect_silent_clients() hourly. See
-- docs/09_Supabase_APNs_Setup.md.
-- ============================================================================
