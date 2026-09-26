// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// apple-link — store the caller's Apple refresh token so account deletion can revoke it later
// (Apple TN3159 / Guideline 5.1.1(v)). Called best-effort by the app right after Sign in with
// Apple, passing Apple's one-time authorizationCode.
//
// Authenticates the caller from their JWT (the token is stored against THAT user only). No-ops
// with 200 if Apple SiwA secrets aren't configured, so the sign-in path never breaks because of it.
//
// The refresh token is written here and read only by delete-account, both service-role. No client
// ever reads it back (apple_tokens has RLS on with no policies — see migration 09_apple_tokens.sql).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { appleConfigured, exchangeAppleCode } from "../_shared/apple.ts";

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

    // If Apple revocation isn't configured, succeed quietly — nothing to store.
    if (!appleConfigured()) return json({ ok: true, skipped: "not_configured" }, 200);

    const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
    if (!token) return json({ error: "missing_authorization" }, 401);

    const { code } = await req.json().catch(() => ({ code: null }));
    if (!code || typeof code !== "string") return json({ error: "missing_code" }, 400);

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { data: userData, error: userErr } = await admin.auth.getUser(token);
    const uid = userData?.user?.id;
    if (userErr || !uid) return json({ error: "invalid_token" }, 401);

    const refresh = await exchangeAppleCode(code);
    if (!refresh) return json({ ok: true, skipped: "no_refresh" }, 200);

    await admin.from("apple_tokens").upsert({
      user_id: uid,
      refresh_token: refresh,
      updated_at: new Date().toISOString(),
    });
    return json({ ok: true }, 200);
  } catch (e) {
    console.error(e);
    return json({ error: "error" }, 500);
  }
});
