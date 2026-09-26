// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// _shared/apple.ts — Sign in with Apple: client-secret JWT, authorization-code exchange, and
// token revocation (Apple TN3159). Used so Pawl can fully honor Guideline 5.1.1(v): when a user
// deletes their account we revoke the Apple refresh token, removing Pawl from their Apple ID →
// "Sign in with Apple" list.
//
// Secrets required to ENABLE (ALL optional — every export below no-ops gracefully if any is
// missing, so account deletion keeps working even when revocation isn't configured):
//   APPLE_TEAM_ID    — 10-char Apple Developer Team ID (e.g. 8C4BM6A82T)
//   APPLE_KEY_ID     — Key ID of a .p8 key that has "Sign in with Apple" enabled
//   APPLE_P8         — the .p8 private-key PEM (may be the SAME key used for APNs IF that key also
//                      has Sign in with Apple enabled; otherwise generate a separate key)
//   APPLE_CLIENT_ID  — the SiwA client_id = the app's bundle id (io.github.jasonepage.Pawl)
//
// To set them:  supabase secrets set APPLE_TEAM_ID=… APPLE_KEY_ID=… APPLE_CLIENT_ID=… APPLE_P8="$(cat AuthKey_XXXX.p8)"

const APPLE_AUD = "https://appleid.apple.com";

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

interface AppleConfig {
  teamID: string;
  keyID: string;
  p8: string;
  clientID: string;
}

function appleConfig(): AppleConfig | null {
  const teamID = Deno.env.get("APPLE_TEAM_ID");
  const keyID = Deno.env.get("APPLE_KEY_ID");
  const p8 = Deno.env.get("APPLE_P8");
  const clientID = Deno.env.get("APPLE_CLIENT_ID");
  if (!teamID || !keyID || !p8 || !clientID) return null;
  return { teamID, keyID, p8, clientID };
}

/** True if the Apple SiwA secrets are present, i.e. exchange/revoke can run. */
export function appleConfigured(): boolean {
  return appleConfig() !== null;
}

// Build the Apple "client secret": an ES256 JWT signed with the .p8, used as client_secret on the
// /auth/token and /auth/revoke endpoints. Apple allows up to 6 months; we mint a fresh short-lived
// one per call.
async function clientSecret(cfg: AppleConfig): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "ES256", kid: cfg.keyID }));
  const claims = b64url(JSON.stringify({
    iss: cfg.teamID,
    iat: now,
    exp: now + 300,
    aud: APPLE_AUD,
    sub: cfg.clientID,
  }));
  const signingInput = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(cfg.p8),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${b64url(new Uint8Array(sig))}`;
}

/**
 * Exchange the one-time authorizationCode (from ASAuthorizationAppleIDCredential at sign-in) for a
 * long-lived refresh token we can revoke later. Returns the refresh_token, or null if Apple isn't
 * configured or the exchange fails.
 */
export async function exchangeAppleCode(code: string): Promise<string | null> {
  const cfg = appleConfig();
  if (!cfg) return null;
  const secret = await clientSecret(cfg);
  const res = await fetch(`${APPLE_AUD}/auth/token`, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: cfg.clientID,
      client_secret: secret,
      grant_type: "authorization_code",
      code,
    }).toString(),
    signal: AbortSignal.timeout(10_000),   // don't let an Apple-side hang stall the request
  });
  if (!res.ok) {
    console.error("apple token exchange failed:", res.status, await res.text());
    return null;
  }
  const data = await res.json();
  return data.refresh_token ?? null;
}

/**
 * Revoke a stored Apple refresh token so Pawl disappears from the user's "Sign in with Apple" list.
 * Returns true on success, false if not configured or the call fails (caller treats as non-fatal).
 */
export async function revokeAppleToken(refreshToken: string): Promise<boolean> {
  const cfg = appleConfig();
  if (!cfg) return false;
  const secret = await clientSecret(cfg);
  const res = await fetch(`${APPLE_AUD}/auth/revoke`, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: cfg.clientID,
      client_secret: secret,
      token: refreshToken,
      token_type_hint: "refresh_token",
    }).toString(),
    signal: AbortSignal.timeout(10_000),   // best-effort; don't stall account deletion on Apple
  });
  if (!res.ok) {
    console.error("apple revoke failed:", res.status, await res.text());
    return false;
  }
  return true;
}
