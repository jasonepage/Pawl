-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- 12_owner_write_lockdown.sql  (written 2026-09-26, apply once, after 01 to 11)
--
-- Why: the owner policies from schema.sql were `for all`, so a signed-in person could write
-- any column of their own rows straight through the REST API with the session token from
-- their own phone (a proxy on their own device is enough, no jailbreak). That allowed:
--   H1  approving your own unlock request (PATCH unlock_requests status = 'approved')
--   H2  linking yourself as your own sponsor, then approving through decide_unlock
--   H3  linking a stranger as your "sponsor" and sending them false alerts
--   H4  silently removing an active sponsor (no key, no wait, no word to the sponsor)
--   H5  switching off alerts by editing commitments.sponsor_mode / status
--   H6  a future last_heartbeat_at that hides an app deletion forever
--   H7  dismissing your own tamper alert before the sponsor sees it
--
-- The rule after this migration: owners may READ their rows and make the few writes the app
-- actually needs (create a request, cancel a pending request, create or cancel an invite).
-- Everything else goes through SECURITY DEFINER functions or the service role.
--
-- Works with the 2.0 and 2.1 apps. One 2.0 action changes on purpose: "Remove sponsor"
-- from the protected person's side no longer works. The sponsor steps down from their side
-- (revoke_sponsorship), or the person deletes their account. 2.1 explains this in the app.
--
-- Known limits that stay: record_heartbeat trusts the phone, and set_hard_lock(false) still
-- lets the owner clear the hard lock attestation (it only changes how urgent an alert is).
-- A script holding the user's own session can keep sending beats. That is in the README.
-- Also: "Remove sponsor" in the 2.0 app now does nothing and the link reappears on refresh.
--
-- Idempotent; safe to run more than once.

begin;

-- ============================================================================
-- H2  nobody can sponsor themselves
-- ============================================================================
-- Retire any self-links that already exist, so the constraint holds for every row.
update public.sponsor_links
   set status = 'revoked', sponsor_id = null, updated_at = now()
 where sponsor_id = user_id;
alter table public.sponsor_links drop constraint if exists sponsor_links_no_self;
alter table public.sponsor_links
  add constraint sponsor_links_no_self check (sponsor_id is distinct from user_id);

create or replace function public.is_sponsor_of(target uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.sponsor_links sl
    where sl.user_id = target
      and sl.sponsor_id = auth.uid()
      and sl.sponsor_id <> sl.user_id
      and sl.status = 'active'
  );
$$;

create or replace function public.decide_unlock(request_id uuid, approved boolean)
returns public.unlock_requests
language plpgsql security definer set search_path = public as $$
declare req public.unlock_requests;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into req from public.unlock_requests where id = request_id;
  if req.id is null then raise exception 'request_not_found'; end if;
  if req.user_id = auth.uid() then raise exception 'not_authorized'; end if;
  if not public.is_sponsor_of(req.user_id) then raise exception 'not_authorized'; end if;
  if req.status <> 'pending' then raise exception 'already_decided'; end if;
  if req.expires_at <= now() then raise exception 'request_expired'; end if;

  update public.unlock_requests
     set status = case when approved then 'approved' else 'denied' end,
         decided_by = auth.uid(),
         decided_at = now()
   where id = request_id
  returning * into req;

  return req;
end; $$;

-- ============================================================================
-- H1  unlock_requests: owner may read, insert a fresh pending request, and cancel it
-- ============================================================================
drop policy if exists unlock_requests_self   on public.unlock_requests;
drop policy if exists unlock_requests_select on public.unlock_requests;
drop policy if exists unlock_requests_insert on public.unlock_requests;
drop policy if exists unlock_requests_cancel on public.unlock_requests;

create policy unlock_requests_select on public.unlock_requests
  for select using (user_id = auth.uid());

create policy unlock_requests_insert on public.unlock_requests
  for insert with check (
    user_id = auth.uid()
    and exists (select 1 from public.commitments c
                where c.id = commitment_id and c.user_id = auth.uid())
  );

create policy unlock_requests_cancel on public.unlock_requests
  for update using (user_id = auth.uid() and status = 'pending')
  with check (user_id = auth.uid() and status = 'cancelled'
              and decided_by is null and decided_at is null);

-- Server-owned columns on a client insert. current_user is 'authenticated' for REST calls
-- and the function owner inside SECURITY DEFINER functions, so server paths are untouched.
create or replace function public.unlock_requests_client_insert()
returns trigger language plpgsql set search_path = public as $$
begin
  if current_user = 'authenticated' then
    new.status              := 'pending';
    new.decided_by          := null;
    new.decided_at          := null;
    new.cooling_off_ends_at := null;
    new.grace_ends_at       := null;
    new.outcome             := 'pending';
    new.requested_at        := now();
    new.created_at          := now();
    new.expires_at          := now() + interval '60 minutes';
  end if;
  return new;
end; $$;
drop trigger if exists trg_unlock_requests_client_insert on public.unlock_requests;
create trigger trg_unlock_requests_client_insert
  before insert on public.unlock_requests
  for each row execute function public.unlock_requests_client_insert();

-- A cancel may only change status (the policy already pins it to 'cancelled').
create or replace function public.unlock_requests_client_update()
returns trigger language plpgsql set search_path = public as $$
begin
  if current_user = 'authenticated' then
    new.id := old.id; new.user_id := old.user_id; new.commitment_id := old.commitment_id;
    new.kind := old.kind; new.requested_at := old.requested_at; new.expires_at := old.expires_at;
    new.created_at := old.created_at; new.outcome := old.outcome;
    new.cooling_off_ends_at := old.cooling_off_ends_at; new.grace_ends_at := old.grace_ends_at;
  end if;
  return new;
end; $$;
drop trigger if exists trg_unlock_requests_client_update on public.unlock_requests;
create trigger trg_unlock_requests_client_update
  before update on public.unlock_requests
  for each row execute function public.unlock_requests_client_update();

-- ============================================================================
-- H3 + H4  sponsor_links: owner may read, create a pending invite, and cancel a PENDING one
-- ============================================================================
drop policy if exists sponsor_links_owner         on public.sponsor_links;
drop policy if exists sponsor_links_owner_select  on public.sponsor_links;
drop policy if exists sponsor_links_owner_insert  on public.sponsor_links;
drop policy if exists sponsor_links_owner_cancel  on public.sponsor_links;

create policy sponsor_links_owner_select on public.sponsor_links
  for select using (user_id = auth.uid());

create policy sponsor_links_owner_insert on public.sponsor_links
  for insert with check (user_id = auth.uid() and sponsor_id is null and status = 'pending');

create policy sponsor_links_owner_cancel on public.sponsor_links
  for update using (user_id = auth.uid() and status = 'pending')
  with check (user_id = auth.uid() and status = 'revoked' and sponsor_id is null);
-- (sponsor_links_sponsor_read from schema.sql stays. Active links change only through
--  redeem_invite and revoke_sponsorship.)

create or replace function public.sponsor_links_client_write()
returns trigger language plpgsql set search_path = public as $$
begin
  if current_user = 'authenticated' then
    if tg_op = 'INSERT' then
      new.sponsor_id  := null;
      new.status      := 'pending';
      new.accepted_at := null;
      new.expires_at  := now() + interval '7 days';
      new.created_at  := now();
    else
      new.id := old.id; new.user_id := old.user_id; new.sponsor_id := old.sponsor_id;
      new.invite_code := old.invite_code; new.expires_at := old.expires_at;
      new.accepted_at := old.accepted_at; new.created_at := old.created_at;
    end if;
    new.updated_at := now();
  end if;
  return new;
end; $$;
drop trigger if exists trg_sponsor_links_client_write on public.sponsor_links;
create trigger trg_sponsor_links_client_write
  before insert or update on public.sponsor_links
  for each row execute function public.sponsor_links_client_write();

-- ============================================================================
-- H5  commitments: the client can no longer set sponsor_mode or the hard lock fields,
--     and alerts no longer depend on them (they follow the active sponsor link instead)
-- ============================================================================
create or replace function public.commitments_client_write()
returns trigger language plpgsql set search_path = public as $$
declare prev public.commitments;
begin
  if current_user = 'authenticated' then
    if tg_op = 'UPDATE' then
      new.sponsor_mode          := old.sponsor_mode;
      new.hard_lock_active      := old.hard_lock_active;
      new.hard_lock_attested_at := old.hard_lock_attested_at;
      new.hard_lock_attested_by := old.hard_lock_attested_by;
      new.user_id               := old.user_id;
    else
      -- A new commitment ("start over") keeps the sponsor and hard lock state of the newest
      -- earlier commitment, active or not.
      select * into prev from public.commitments
       where user_id = new.user_id
       order by updated_at desc limit 1;
      new.sponsor_mode := exists (select 1 from public.sponsor_links sl
                                  where sl.user_id = new.user_id and sl.status = 'active'
                                    and sl.sponsor_id <> sl.user_id);
      new.hard_lock_active      := coalesce(prev.hard_lock_active, false);
      new.hard_lock_attested_at := prev.hard_lock_attested_at;
      new.hard_lock_attested_by := prev.hard_lock_attested_by;
    end if;
  end if;
  return new;
end; $$;
drop trigger if exists trg_commitments_client_write on public.commitments;
create trigger trg_commitments_client_write
  before insert or update on public.commitments
  for each row execute function public.commitments_client_write();

-- Alerts follow the sponsor link, not a column the owner can edit or a row they can delete.
create or replace function public.report_auth_lost()
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if exists (
        select 1 from public.sponsor_links sl
        where sl.user_id = auth.uid() and sl.status = 'active' and sl.sponsor_id <> sl.user_id)
     and not exists (
        select 1 from public.tamper_alerts t
        where t.user_id = auth.uid() and t.kind = 'auth_lost'
          and t.resolved_at is null and t.recovered_at is null)
  then
    insert into public.tamper_alerts (user_id, kind, hard_locked)
    values (auth.uid(), 'auth_lost',
            coalesce((select c.hard_lock_active from public.commitments c
                      where c.user_id = auth.uid() and c.status = 'active'
                      order by c.updated_at desc limit 1), false))
    on conflict (user_id, kind) where resolved_at is null and recovered_at is null do nothing;
  end if;
end; $$;

-- ============================================================================
-- H6  devices / heartbeats: read only for the owner; writes only through record_heartbeat.
--     A heartbeat stamped in the future no longer counts as "still alive".
-- ============================================================================
drop policy if exists devices_self    on public.devices;
drop policy if exists devices_select  on public.devices;
create policy devices_select on public.devices for select using (user_id = auth.uid());

drop policy if exists heartbeats_self   on public.heartbeats;
drop policy if exists heartbeats_select on public.heartbeats;
create policy heartbeats_select on public.heartbeats for select using (user_id = auth.uid());

create or replace function public.detect_silent_clients(threshold interval default interval '24 hours')
returns setof public.tamper_alerts
language plpgsql security definer set search_path = public as $$
begin
  return query
  insert into public.tamper_alerts (user_id, kind, detected_at, hard_locked)
  select u.user_id, 'silence', now(),
         coalesce((select c.hard_lock_active from public.commitments c
                   where c.user_id = u.user_id and c.status = 'active'
                   order by c.updated_at desc limit 1), false)
  from (select distinct sl.user_id from public.sponsor_links sl
        where sl.status = 'active' and sl.sponsor_id <> sl.user_id) u
  where (
      select least(coalesce(max(d.last_heartbeat_at), 'epoch'), now())
      from public.devices d where d.user_id = u.user_id
    ) < now() - threshold
    and not exists (
      select 1 from public.tamper_alerts t
      where t.user_id = u.user_id and t.kind = 'silence'
        and t.resolved_at is null and t.recovered_at is null
    )
  on conflict (user_id, kind) where resolved_at is null and recovered_at is null do nothing
  returning *;
end; $$;

-- ============================================================================
-- has_active_sponsor: lets the 2.1 app stop waiting for a sponsor on an account that was
-- signed out of or deleted elsewhere. Returns only a yes/no for a UUID the caller already has.
-- ============================================================================
create or replace function public.has_active_sponsor(target uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.sponsor_links sl
    where sl.user_id = target and sl.status = 'active' and sl.sponsor_id <> sl.user_id
  );
$$;

-- ============================================================================
-- H7  only an active sponsor can dismiss an alert while a sponsor exists
-- ============================================================================
create or replace function public.resolve_tamper_alert(alert_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare a public.tamper_alerts;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into a from public.tamper_alerts where id = alert_id;
  if a.id is null then return; end if;
  if public.is_sponsor_of(a.user_id) then
    null;                                            -- the active sponsor may always dismiss
  elsif a.user_id = auth.uid() and not exists (
          select 1 from public.sponsor_links sl
          where sl.user_id = a.user_id and sl.status = 'active' and sl.sponsor_id <> sl.user_id) then
    null;                                            -- the owner, only when nobody sponsors them
  else
    raise exception 'not_authorized';
  end if;
  update public.tamper_alerts
     set resolved_at = now()
   where id = alert_id and resolved_at is null;
end; $function$;

-- ============================================================================
-- Grants: keep the 11_ pattern (signed-in callers only) for everything redefined here.
-- ============================================================================
do $$
declare f text;
begin
  foreach f in array array[
    'public.decide_unlock(uuid, boolean)',
    'public.has_active_sponsor(uuid)',
    'public.report_auth_lost()',
    'public.resolve_tamper_alert(uuid)'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated, service_role', f);
  end loop;
end $$;
revoke execute on function public.detect_silent_clients(interval) from public, anon, authenticated;
grant  execute on function public.detect_silent_clients(interval) to service_role;
revoke execute on function public.unlock_requests_client_insert() from public, anon, authenticated;
revoke execute on function public.unlock_requests_client_update() from public, anon, authenticated;
revoke execute on function public.sponsor_links_client_write()    from public, anon, authenticated;
revoke execute on function public.commitments_client_write()      from public, anon, authenticated;

commit;
