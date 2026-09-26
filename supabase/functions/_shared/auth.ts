// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// _shared/auth.ts — who is calling, decided from their own token and nothing else.
//
// Every Edge Function runs with verify_jwt = true, so the platform has already checked
// the token's signature. That alone is not enough: the public anon key is also a valid
// token. This resolves the token to a real signed in user, or returns null.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

export function bearer(req: Request): string {
  const header = req.headers.get("Authorization") ?? "";
  return header.startsWith("Bearer ") ? header.slice(7).trim() : "";
}

/** The signed in user's id, or null for the anon key, an expired token, or no token. */
export async function callerID(req: Request): Promise<string | null> {
  const token = bearer(req);
  if (!token) return null;
  const asCaller = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: `Bearer ${token}` } } },
  );
  const { data, error } = await asCaller.auth.getUser();
  return error ? null : data?.user?.id ?? null;
}
