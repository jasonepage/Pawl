// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// _shared/apns.ts — APNs token-based push sender for Pawl Edge Functions.
//
// Signs an ES256 provider JWT from the .p8 stored in Edge Function secrets and sends an
// alert push over HTTP/2. Secrets required: APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID,
// APNS_P8 (full PEM), APNS_ENV ("sandbox" | "production").

function b64url(input: Uint8Array | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToPkcs8(pem: string): ArrayBuffer {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const bin = atob(body);
  const buf = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
  return buf.buffer;
}

let cachedJWT: { token: string; iat: number } | null = null;

async function providerJWT(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  // APNs accepts a provider token for up to ~1h; reuse within 50 min.
  if (cachedJWT && now - cachedJWT.iat < 3000) return cachedJWT.token;

  const keyID = Deno.env.get("APNS_KEY_ID")!;
  const teamID = Deno.env.get("APNS_TEAM_ID")!;
  const p8 = Deno.env.get("APNS_P8")!;

  const header = b64url(JSON.stringify({ alg: "ES256", kid: keyID }));
  const claims = b64url(JSON.stringify({ iss: teamID, iat: now }));
  const signingInput = `${header}.${claims}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(p8),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  const token = `${signingInput}.${b64url(new Uint8Array(sig))}`;
  cachedJWT = { token, iat: now };
  return token;
}

export async function sendPush(
  deviceToken: string,
  title: string,
  body: string,
  opts: { category?: string; data?: Record<string, unknown> } = {},
): Promise<boolean> {
  const env = Deno.env.get("APNS_ENV") ?? "sandbox";
  const host = env === "production" ? "api.push.apple.com" : "api.sandbox.push.apple.com";
  const jwt = await providerJWT();

  // `category` drives the Approve/Deny action buttons on the client; `data` (e.g. request_id)
  // is merged at the top level so the action handler can read it from userInfo.
  const aps: Record<string, unknown> = { alert: { title, body }, sound: "default" };
  if (opts.category) aps.category = opts.category;

  const res = await fetch(`https://${host}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": Deno.env.get("APNS_BUNDLE_ID")!,
      "apns-push-type": "alert",
      "apns-priority": "10",
    },
    body: JSON.stringify({ aps, ...(opts.data ?? {}) }),
  });

  if (!res.ok) {
    console.error(`APNs ${res.status}: ${await res.text()} (token ${deviceToken.slice(0, 8)}…)`);
    return false;
  }
  return true;
}
