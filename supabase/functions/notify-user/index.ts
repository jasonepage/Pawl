// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// notify-user — push the requester when their sponsor approves or denies.
// Invoked by the sponsor's client right after decide_unlock (FR-P2-NOTIF-003).
//
// SECURITY FIX 2026-09-25. Before this, the function trusted any caller holding a valid
// token (the public anon key counts as one) and took "approved" from the request body.
// Anyone who learned a request id could send the requester a fake "Sponsor approved"
// push. It never unlocked anything, but a false yes is exactly the message a person in
// recovery should never get. Now only an active sponsor of that user can trigger it, and
// the outcome is read from the database, never from what the caller sends.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { sendPush } from "../_shared/apns.ts";
import { callerID } from "../_shared/auth.ts";

Deno.serve(async (req) => {
  try {
    const me = await callerID(req);
    if (!me) return new Response("unauthorized", { status: 401 });

    const { request_id } = await req.json();
    if (!request_id) return new Response("missing request_id", { status: 400 });

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: reqRow } = await supabase
      .from("unlock_requests").select("user_id,status").eq("id", request_id).single();
    if (!reqRow) return new Response("not found", { status: 404 });

    const { data: link } = await supabase
      .from("sponsor_links").select("id")
      .eq("user_id", reqRow.user_id).eq("sponsor_id", me).eq("status", "active")
      .maybeSingle();
    if (!link) return new Response("forbidden", { status: 403 });

    if (reqRow.status !== "approved" && reqRow.status !== "denied") {
      return new Response("not decided", { status: 200 });
    }
    const approved = reqRow.status === "approved";

    const { data: devices } = await supabase
      .from("devices").select("apns_token").eq("user_id", reqRow.user_id)
      .not("apns_token", "is", null);

    const title = approved ? "Sponsor approved" : "Sponsor denied";
    const body = approved
      ? "Your 15-minute cooling-off has started."
      : "Your shield stays on.";

    for (const d of devices ?? []) {
      await sendPush(d.apns_token, title, body);
    }
    return new Response("ok", { status: 200 });
  } catch (e) {
    console.error(e);
    return new Response("error", { status: 500 });
  }
});
