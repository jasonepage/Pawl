-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- 02_blocklist.sql — Tier-1 blocklist expansion (docs/Blocklist_Expansion_Plan.md)
--
-- A maintained gambling-domain list the app fetches on launch and merges into its Screen Time
-- webContent filter, so the list grows WITHOUT shipping a new app build. Public, read-only data
-- (it's a shared blocklist, not user data): anyone with the anon key can read; only the service
-- role (the ingest job) can write. The app still ships GamblingBlocklist.seedDomains as the
-- offline fallback, and BlocklistService unions the seed in, so this table only needs the
-- *additional* domains.
--
-- Run after schema.sql + 01_heartbeat.sql. Populate it via the ingest runbook in
-- docs/Blocklist_Expansion_Plan.md (HaGeZi Gambling list, trimmed to a device-safe top-N).

create table if not exists public.blocklist_domains (
    domain     text primary key,
    category   text not null default 'gambling',   -- future: 'adult', etc.
    source     text,                                -- e.g. 'hagezi', 'seed', 'partner:<name>'
    added_at   timestamptz not null default now()
);

create index if not exists blocklist_domains_category_idx
    on public.blocklist_domains (category);

alter table public.blocklist_domains enable row level security;

-- Public read; no public write (service role bypasses RLS for ingest).
drop policy if exists "blocklist readable by anyone" on public.blocklist_domains;
create policy "blocklist readable by anyone"
    on public.blocklist_domains
    for select
    using (true);

-- Optional sanity seed so the table is non-empty before the HaGeZi import runs. These overlap
-- the app's seedDomains (harmless — the client dedupes). Expand via the ingest runbook.
insert into public.blocklist_domains (domain, category, source) values
    ('bet365.com',     'gambling', 'seed'),
    ('draftkings.com', 'gambling', 'seed'),
    ('fanduel.com',    'gambling', 'seed'),
    ('stake.com',      'gambling', 'seed'),
    ('bovada.lv',      'gambling', 'seed')
on conflict (domain) do nothing;
