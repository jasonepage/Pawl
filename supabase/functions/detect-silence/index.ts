// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// detect-silence — two callers, two very different jobs.
//
//   1. The hourly pg_cron job, calling with the SERVICE ROLE key. Runs the fleet wide
//      silence sweep, then pushes every un-notified open tamper alert (silence OR
//      auth_lost) and marks it notified (FR-P2-HEART-003/004, HC-6).
//
//   2. A signed in user's app, calling with their own JWT right after Screen Time drops,
//      so their sponsor is pushed immediately instead of waiting up to an hour. This path
//      is scoped to that ONE user and never runs the sweep.
//
// SECURITY FIX 2026-09-03. Before this, the handler took no argument and checked nothing:
// it ran the fleet wide sweep with the service role key for anyone who could reach the
// endpoint. Combined with HeartbeatService invoking it on a user token, any signed in user
// could push every sponsor in the project on demand, which is a false alarm cannon aimed at
// the exact notification the product needs people to trust. The SQL half of this was fixed
// in migration 10 by revoking EXECUTE on detect_silent_clients from PUBLIC; this is the
// other half. See docs/PAWL_STATUS_2026-08-16.md section 3.2.
//
// 2026-09-26: the first deploy of that fix rejected the cron job for six hours, because
// the cron's key and SUPABASE_SERVICE_ROLE_KEY are different strings. isServiceKey()
// below handles both. No alerts were missed: no active commitment had a sponsor then.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { sendPush } from "../_shared/apns.ts";

const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

/** Constant time compare, so the service key cannot be probed a byte at a time. */
function sameSecret(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/**
 * True only for a real service role key. The cron job stores the project's legacy
 * service_role JWT, and on this project that is not the same string the platform puts
 * in SUPABASE_SERVICE_ROLE_KEY (confirmed 2026-09-26). So when the plain compare fails,
 * a token that claims role service_role is proven by using it: the Auth admin endpoint
 * answers only to a genuine service key. A signed in user's token never claims it.
 */
async function isServiceKey(token: string): Promise<boolean> {
  if (sameSecret(token, SERVICE_KEY)) return true;
  const parts = token.split(".");
  if (parts.length !== 3) return false;
  let role = "";
  try {
    const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    role = JSON.parse(atob(b64 + "=".repeat((4 - (b64.length % 4)) % 4)))?.role ?? "";
  } catch {
    return false;
  }
  if (role !== "service_role") return false;
  const probe = createClient(SUPABASE_URL, token);
  const { error } = await probe.auth.admin.listUsers({ page: 1, perPage: 1 });
  return !error;
}

function bearer(req: Request): string {
  const header = req.headers.get("Authorization") ?? "";
  return header.startsWith("Bearer ") ? header.slice(7).trim() : "";
}

/**
 * Push sponsors for open, un-notified alerts and mark them notified.
 * When userID is null this covers every user (cron). When it is set, only that user.
 */
async function pushOpenAlerts(
  supabase: ReturnType<typeof createClient>,
  userID: string | null,
): Promise<number> {
  let query = supabase
    .from("tamper_alerts")
    .select("id,user_id,kind,hard_locked")
    .is("resolved_at", null)
    .eq("notified", false);

  if (userID) query = query.eq("user_id", userID);

  const { data: alerts } = await query;
  let pushed = 0;

  for (const a of alerts ?? []) {
    const { data: links } = await supabase
      .from("sponsor_links").select("sponsor_id")
      .eq("user_id", a.user_id).eq("status", "active");
    const sponsorIDs = (links ?? []).map((l) => l.sponsor_id).filter(Boolean);

    if (sponsorIDs.length > 0) {
      const { data: prof } = await supabase
        .from("profiles").select("display_name").eq("id", a.user_id).single();
      const who = prof?.display_name || "Someone you sponsor";
      const { data: devices } = await supabase
        .from("devices").select("apns_token").in("user_id", sponsorIDs)
        .not("apns_token", "is", null);
      const base = a.kind === "auth_lost"
        ? `${who} turned off Screen Time.`
        : `${who}'s app went silent. It may be deleted.`;
      const msg = a.hard_locked ? `URGENT. Hard lock breached. ${base}` : base;
      const title = a.hard_locked ? "Pawl protection breached" : "Pawl protection alert";
      for (const d of devices ?? []) {
        await sendPush(d.apns_token, title, msg);
        pushed++;
      }
    }
    await supabase.from("tamper_alerts").update({ notified: true }).eq("id", a.id);
  }
  return pushed;
}

Deno.serve(async (req) => {
  try {
    const token = bearer(req);
    if (!token) return new Response("unauthorized", { status: 401 });

    const admin = createClient(SUPABASE_URL, SERVICE_KEY);

    // Path 1: the cron job. Only the service role gets the fleet wide sweep.
    if (await isServiceKey(token)) {
      await admin.rpc("detect_silent_clients");
      const pushed = await pushOpenAlerts(admin, null);
      return new Response(JSON.stringify({ scope: "fleet", pushed }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Path 2: a signed in user. Resolve who they actually are from their own token,
    // never from anything they send in the body, and scope the work to them.
    const asCaller = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const { data: userData, error: userErr } = await asCaller.auth.getUser();
    const callerID = userData?.user?.id;
    if (userErr || !callerID) return new Response("unauthorized", { status: 401 });

    // Deliberately does NOT call detect_silent_clients. A user may push their own pending
    // alerts early; they may not start a sweep, and they may not touch anyone else's rows.
    const pushed = await pushOpenAlerts(admin, callerID);
    return new Response(JSON.stringify({ scope: "self", pushed }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error(e);
    return new Response("error", { status: 500 });
  }
});
