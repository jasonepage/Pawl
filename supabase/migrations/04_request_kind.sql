-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- 04_request_kind.sql — label what each unlock_request is actually asking for, so the sponsor
-- sees "wants to remove a blocked app" instead of a generic "Unlock requested" (FR-P2-SPON-008).
-- Run in the Supabase SQL editor.

alter table public.unlock_requests
  add column if not exists kind text not null default 'unlock';

-- Constrain to the known kinds (drop first so re-runs don't error on an existing constraint).
alter table public.unlock_requests
  drop constraint if exists unlock_requests_kind_check;
alter table public.unlock_requests
  add constraint unlock_requests_kind_check
  check (kind in ('unlock', 'remove_app', 'disable_category'));
