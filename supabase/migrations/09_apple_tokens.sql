-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- 09_account_deletion.sql — support for full account deletion (Guideline 5.1.1(v)).
-- ----------------------------------------------------------------------------
-- Two things:
--   (A) A required FK FIX so deletion can't fail for sponsors (see below).
--   (B) The OPTIONAL Apple-token store used to revoke Sign in with Apple on deletion (TN3159).
--
-- DELETION OF OWNED DATA needs no schema change: every table in schema.sql references
-- auth.users(id) ON DELETE CASCADE (directly or via commitments), so admin.deleteUser(uid) removes
-- profiles, sponsor_links, commitments, block_sets, unlock_requests, devices, heartbeats,
-- tamper_alerts, webauthn_credentials, relapse_events, urge_events in one shot. (Verified 2026-06-28.)
--
-- BUT one FK pointed the wrong way: unlock_requests.decided_by → auth.users(id) had no ON DELETE
-- rule (defaults to NO ACTION). A sponsor who has approved/denied someone else's unlock request is
-- referenced by that other person's row, which the cascade does NOT remove — so deleting the
-- SPONSOR's account would raise a FK violation and fail. (A) re-points it to ON DELETE SET NULL so
-- the account deletes cleanly while the decision record survives with a blank decider.
-- This migration is safe to run even if you skip Apple revocation — the apple_tokens table just
-- stays empty.
-- ----------------------------------------------------------------------------

-- ----------------------------------------------------------------------------
-- (A) FK FIX — unlock_requests.decided_by must SET NULL on delete, or sponsors can't delete.
-- Defensive: look up the real constraint name (auto-generated) before dropping it.
-- ----------------------------------------------------------------------------
do $$
declare cname text;
begin
  select con.conname into cname
  from pg_constraint con
  join pg_attribute att
    on att.attrelid = con.conrelid and att.attnum = any(con.conkey)
  where con.conrelid = 'public.unlock_requests'::regclass
    and con.contype = 'f'
    and att.attname = 'decided_by';
  if cname is not null then
    execute format('alter table public.unlock_requests drop constraint %I', cname);
  end if;
end $$;

alter table public.unlock_requests
  add constraint unlock_requests_decided_by_fkey
  foreign key (decided_by) references auth.users(id) on delete set null;

-- ----------------------------------------------------------------------------
-- (B) Apple-token store (optional — only used when the APPLE_* Edge Function secrets are set).
-- ----------------------------------------------------------------------------
-- apple_tokens — one Apple refresh token per user, written by `apple-link` at sign-in and read by
-- `delete-account` to revoke. Service-role only: RLS is ENABLED with NO policies, so no signed-in
-- client can ever read or write a refresh token; only the Edge Functions (service role) touch it.
create table if not exists public.apple_tokens (
  user_id       uuid primary key references auth.users(id) on delete cascade,
  refresh_token text not null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

alter table public.apple_tokens enable row level security;
-- Intentionally NO policies. (Belt-and-suspenders: revoke any default grants from app roles.)
revoke all on public.apple_tokens from anon, authenticated;

-- ----------------------------------------------------------------------------
-- Optional sanity check — confirm everything cascades off auth.users as expected.
-- Run this SELECT after applying; every public.* table holding user data should appear with
-- delete_rule = CASCADE (sponsor_links.sponsor_id is the one intentional SET NULL).
-- ----------------------------------------------------------------------------
-- select tc.table_name, kcu.column_name, rc.delete_rule
-- from information_schema.table_constraints tc
-- join information_schema.key_column_usage kcu on kcu.constraint_name = tc.constraint_name
-- join information_schema.referential_constraints rc on rc.constraint_name = tc.constraint_name
-- join information_schema.constraint_column_usage ccu on ccu.constraint_name = tc.constraint_name
-- where tc.constraint_type = 'FOREIGN KEY' and ccu.table_name = 'users' and ccu.table_schema = 'auth'
-- order by tc.table_name;
