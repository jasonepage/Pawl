-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- 03_cleanup.sql — robustness cleanup (run in the Supabase SQL editor, once)
--
-- 1. Enforce ONE active commitment per user. The dev "Start over" flow created a fresh active
--    commitment each time, so users accumulated duplicates → duplicate tamper alerts
--    (the `select distinct` in detect_silent_clients masked the symptom; this fixes the cause).
-- 2. One-time dedupe of any existing duplicates.
-- 3. Sponsor-side revoke RPC (FR-P2-LINK-004) — lets a sponsor step down; was user-side only.

-- ----------------------------------------------------------------------------
-- 1. Trigger: when a commitment becomes active, deactivate the user's other actives.
-- ----------------------------------------------------------------------------
create or replace function public.enforce_single_active_commitment()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'active' then
    update public.commitments
       set status = 'inactive', updated_at = now()
     where user_id = new.user_id
       and id <> new.id
       and status = 'active';
  end if;
  return new;   -- AFTER trigger; the inner update sets others to 'inactive' so it can't recurse
end; $$;

drop trigger if exists trg_single_active_commitment on public.commitments;
create trigger trg_single_active_commitment
  after insert or update of status on public.commitments
  for each row execute function public.enforce_single_active_commitment();

-- ----------------------------------------------------------------------------
-- 2. One-time dedupe: keep the newest active commitment per user, deactivate older ones.
-- ----------------------------------------------------------------------------
update public.commitments c
   set status = 'inactive', updated_at = now()
 where c.status = 'active'
   and c.id <> (
     select c2.id from public.commitments c2
      where c2.user_id = c.user_id and c2.status = 'active'
      order by c2.started_at desc, c2.updated_at desc
      limit 1
   );

-- ----------------------------------------------------------------------------
-- 3. revoke_sponsorship: the active sponsor steps down (FR-P2-LINK-004).
--    Mirrors redeem_invite's least-privilege pattern (SECURITY DEFINER, scoped to the caller).
-- ----------------------------------------------------------------------------
create or replace function public.revoke_sponsorship(link_id uuid)
returns public.sponsor_links
language plpgsql security definer set search_path = public as $$
declare link public.sponsor_links;
begin
  update public.sponsor_links
     set status = 'revoked', updated_at = now()
   where id = link_id
     and sponsor_id = auth.uid()      -- only the sponsor on this link may revoke it
     and status = 'active'
  returning * into link;

  if link.id is null then
    raise exception 'not_authorized_or_not_active';
  end if;

  -- Downgrade the user's commitment to solo only if no OTHER active sponsor remains.
  if not exists (
       select 1 from public.sponsor_links sl
        where sl.user_id = link.user_id and sl.status = 'active'
     ) then
    update public.commitments
       set sponsor_mode = false, updated_at = now()
     where user_id = link.user_id and status = 'active';
  end if;

  return link;
end; $$;
