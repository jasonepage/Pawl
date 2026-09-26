// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// notify-sponsor — push the linked sponsor(s) when an unlock_request is created.
// Invoked by the requesting client right after createRequest (FR-P2-NOTIF-003).
//
// SECURITY FIX 2026-09-25. Before this, the function trusted any caller holding a valid
// token, and the public anon key counts as one. Anyone who learned a request id could make
// a sponsor's phone ring again and again. Now only the person who made the request can
// trigger the push, and only while the request is still pending.

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
    if (reqRow.user_id !== me) return new Response("forbidden", { status: 403 });
    if (reqRow.status !== "pending") return new Response("not pending", { status: 200 });

    const { data: links } = await supabase
      .from("sponsor_links").select("sponsor_id")
      .eq("user_id", reqRow.user_id).eq("status", "active");
    const sponsorIDs = (links ?? []).map((l) => l.sponsor_id).filter(Boolean);
    if (sponsorIDs.length === 0) return new Response("no sponsor", { status: 200 });

    const { data: prof } = await supabase
      .from("profiles").select("display_name").eq("id", reqRow.user_id).single();
    const who = prof?.display_name || "Someone you sponsor";

    const { data: devices } = await supabase
      .from("devices").select("apns_token").in("user_id", sponsorIDs)
      .not("apns_token", "is", null);

    for (const d of devices ?? []) {
      await sendPush(d.apns_token, "Pawl unlock request", `${who} wants to unlock. Approve or deny.`, {
        category: "UNLOCK_REQUEST",
        data: { request_id },
      });
    }
    return new Response("ok", { status: 200 });
  } catch (e) {
    console.error(e);
    return new Response("error", { status: 500 });
  }
});
