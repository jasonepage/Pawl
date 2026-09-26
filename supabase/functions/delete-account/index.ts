// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// delete-account — permanently delete the caller's account and ALL their data.
// Satisfies App Store Guideline 5.1.1(v) (Data Collection and Storage — account deletion).
//
// SECURITY: the account to delete is taken from the caller's JWT, never from the request body.
// A signed-in user can therefore only ever delete THEMSELVES. The function runs with the service
// role (bypasses RLS) so it can clean up linked rows and call the admin delete API.
//
// Steps:
//   1. Validate the bearer JWT → user id (the only id we act on).
//   2. Best-effort: push the active sponsor that this person deleted their account (accountability).
//   3. Best-effort: revoke the Apple Sign in refresh token (Apple TN3159) if one was stored and
//      Apple SiwA secrets are configured. Non-fatal — deletion proceeds regardless.
//   4. Don't strand anyone this user was SPONSORING: revoke those links + clear their sponsor_mode.
//   5. admin.deleteUser(uid) — cascade-deletes profiles, sponsor_links, commitments, block_sets,
//      unlock_requests, devices, heartbeats, tamper_alerts, webauthn_credentials, relapse_events,
//      urge_events, apple_tokens (every table FKs auth.users(id) ON DELETE CASCADE).
//
// Returns 200 {ok:true} on success. The best-effort steps (2–4) never block deletion.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { sendPush } from "../_shared/apns.ts";
import { revokeAppleToken } from "../_shared/apple.ts";

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

    const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
    if (!token) return json({ error: "missing_authorization" }, 401);

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // 1. Identify the caller from their JWT. This is the ONLY id we act on.
    const { data: userData, error: userErr } = await admin.auth.getUser(token);
    const uid = userData?.user?.id;
    if (userErr || !uid) return json({ error: "invalid_token" }, 401);

    // 2. Best-effort: tell the active sponsor this person is leaving.
    try {
      const { data: prof } = await admin
        .from("profiles").select("display_name").eq("id", uid).maybeSingle();
      const who = prof?.display_name || "Someone you sponsor";

      const { data: links } = await admin
        .from("sponsor_links").select("sponsor_id")
        .eq("user_id", uid).eq("status", "active");
      const sponsorIDs = (links ?? []).map((l) => l.sponsor_id).filter(Boolean);

      if (sponsorIDs.length > 0) {
        const { data: devices } = await admin
          .from("devices").select("apns_token")
          .in("user_id", sponsorIDs).not("apns_token", "is", null);
        for (const d of devices ?? []) {
          await sendPush(
            d.apns_token,
            "Pawl protection ended",
            `${who} deleted their Pawl account. You're no longer their approver.`,
          );
        }
      }
    } catch (e) {
      console.error("sponsor notify failed (non-fatal):", e);
    }

    // 3. Best-effort: revoke the Apple Sign in token so Pawl disappears from the user's
    //    Apple ID → "Sign in with Apple" list (TN3159). No-ops if Apple isn't configured or
    //    the apple_tokens table / row is absent.
    try {
      const { data: tok } = await admin
        .from("apple_tokens").select("refresh_token").eq("user_id", uid).maybeSingle();
      if (tok?.refresh_token) await revokeAppleToken(tok.refresh_token);
    } catch (e) {
      console.error("apple revoke failed (non-fatal):", e);
    }

    // 4. Don't strand people this user was sponsoring: revoke those links and clear sponsor_mode
    //    so they aren't left flagged as a sponsor-mode client with a now-deleted sponsor.
    try {
      const { data: sponsored } = await admin
        .from("sponsor_links").select("user_id")
        .eq("sponsor_id", uid).eq("status", "active");
      const sponsoredIDs = (sponsored ?? []).map((l) => l.user_id).filter(Boolean);
      if (sponsoredIDs.length > 0) {
        const nowISO = new Date().toISOString();
        await admin.from("sponsor_links")
          .update({ status: "revoked", updated_at: nowISO })
          .eq("sponsor_id", uid).eq("status", "active");
        await admin.from("commitments")
          .update({ sponsor_mode: false, updated_at: nowISO })
          .in("user_id", sponsoredIDs).eq("status", "active");
      }
    } catch (e) {
      console.error("sponsor cleanup failed (non-fatal):", e);
    }

    // 5. The actual deletion. Cascades to every public table via FK ON DELETE CASCADE.
    const { error: delErr } = await admin.auth.admin.deleteUser(uid);
    if (delErr) {
      console.error("deleteUser failed:", delErr);
      return json({ error: "delete_failed" }, 500);
    }

    return json({ ok: true }, 200);
  } catch (e) {
    console.error(e);
    return json({ error: "error" }, 500);
  }
});
