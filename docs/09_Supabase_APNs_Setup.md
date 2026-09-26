# 09 — Phase 2 Setup Checklist (Supabase + APNs + Xcode)

**Audience:** whoever runs the backend. **These are the steps only you can do** — Apple Developer portal,
Supabase dashboard, and Xcode capability/target changes. Engineering pauses here until §1–§6 are
green; I can build auth → repository → linking → approval → heartbeat the moment the project URL,
anon key, and APNs key exist.

Work top to bottom. Each step says **where** to click. Check the box when done.

---

## 1. Create the Supabase project
- [ ] Go to https://supabase.com → **New project**. Pick an org, name it `pawl`, choose a region close to you, set a strong DB password (save it).
- [ ] Wait for provisioning (~2 min).
- [ ] **Settings → API**: copy **Project URL** and the **anon public** key. Paste them to me (anon key is safe to ship in-app; RLS protects the data). **Do not** share the `service_role` key — that's for Edge Functions only.

## 2. Run the database schema
- [ ] Open **SQL Editor → New query**.
- [ ] Paste the entire contents of **`supabase/schema.sql`** and click **Run**. It creates all tables, RLS policies, and the RPCs.
- [ ] **Database → Extensions**: enable **`pg_cron`** (needed in §7).
- [ ] Sanity check: **Table editor** should now show `profiles`, `sponsor_links`, `commitments`, `unlock_requests`, `devices`, `heartbeats`, `tamper_alerts`, etc., each with the shield icon (RLS on).

## 3. Apple Developer — enable capabilities & make the APNs key
In https://developer.apple.com/account → **Certificates, Identifiers & Profiles**:
- [ ] **Identifiers → `io.github.jasonepage.Pawl`**: tick **Push Notifications** and **Sign In with Apple**. Save.
- [ ] **Keys → ➕**: create a key, tick **Apple Push Notifications service (APNs)**, Continue → Register → **Download the `.p8`** (you can only download once — keep it safe). Note the **Key ID**.
- [ ] Note your **Team ID** (top-right of the portal; the handoff lists `8C4BM6A82T`).

## 4. Configure Sign in with Apple in Supabase
- [ ] Supabase **Authentication → Providers → Apple**: toggle **Enabled**.
- [ ] In the **Client IDs** field, enter the app bundle id `io.github.jasonepage.Pawl` (native iOS SiwA sends an identity token whose audience is the bundle id; this allows-lists it). Save.
- [ ] (No Services ID / redirect URL is needed for the *native* iOS flow — the app calls `signInWithIdToken(provider: .apple)`. We only need the bundle id allow-listed.)

## 5. Store the APNs key as Edge Function secrets
- [ ] Install the CLI if you like (`brew install supabase/tap/supabase`) **or** use the dashboard.
- [ ] Add these secrets (**Edge Functions → Secrets**, or `supabase secrets set`):
  - `APNS_KEY_ID` = the Key ID from §3
  - `APNS_TEAM_ID` = `8C4BM6A82T`
  - `APNS_BUNDLE_ID` = `io.github.jasonepage.Pawl`
  - `APNS_P8` = the full contents of the `.p8` file (paste the PEM block)
  - `APNS_ENV` = `sandbox` (switch to `production` for TestFlight/App Store)
- [ ] (Edge Function code lands in the next engineering slice; secrets just need to exist.)

## 6. Xcode — add capabilities, the package, and the background-task id
Open `Pawl.xcodeproj`, select the **Pawl** target → **Signing & Capabilities**:
- [ ] **＋ Capability → Sign in with Apple**.
- [ ] **＋ Capability → Push Notifications**.
- [ ] **＋ Capability → Background Modes** → tick **Remote notifications** and **Background processing**.
- [ ] Add the Supabase Swift package: **File → Add Package Dependencies…** → `https://github.com/supabase-community/supabase-swift` → add **Supabase** to the **Pawl** target (only the app target, not the extensions).
- [ ] Register the heartbeat background-task id in **Info** (Pawl target → Info tab, or Info.plist):
  - Key **`BGTaskSchedulerPermittedIdentifiers`** (Array) → one item: `io.github.jasonepage.Pawl.heartbeat`
- [ ] Confirm **App Groups** still shows `group.io.github.jasonepage.Pawl` on all three targets (unchanged from P1).

## 7. Schedule silence detection (after Edge Functions deploy — next slice)
- [ ] Once the `detect-silence` Edge Function is deployed, schedule it hourly. In **SQL Editor**:
  ```sql
  select cron.schedule('pawl-detect-silence', '0 * * * *',
    $$ select net.http_post(
         url := 'https://<PROJECT-REF>.functions.supabase.co/detect-silence',
         headers := jsonb_build_object('Authorization', 'Bearer <SERVICE_ROLE_KEY>')
       ); $$);
  ```
  (Or call `select public.detect_silent_clients();` directly on a cron if you push from SQL.)

---

## What I (engineering) do once §1–§6 are green
In the suggested order, each as a small verifiable slice:
1. **Auth** — Sign in with Apple → Supabase session; create `profiles` row; gate is additive (solo loop still works signed-out, FR-P2-AUTH-005).
2. **Repository swap** — `SupabaseCommitmentRepository: CommitmentRepository`, composed with the iCloud cache; feature code unchanged (FR-P2-SYNC-005).
3. **Sponsor linking** — generate/redeem invite code (`redeem_invite` RPC), sponsor-mode toggle (FR-P2-LINK-*).
4. **Unlock approval gate** — wire `UnlockViewModel` to create `unlock_request` + await the APNs decision; the pure machine already handles `.awaitingApproval`/`.sponsorDecision` (landed).
5. **Heartbeat/tamper** — BGTaskScheduler beats via `record_heartbeat`; Edge Functions `unlock-request-notify`, `decide-unlock`, `detect-silence`.

## Notes / honesty checks (carried constraints)
- The shield/timer never call the network — extensions read the App Group only (HC-6, FR-P2-SYNC-002). Supabase being "source of truth" does not change that.
- Heartbeat **detects** tampering after the fact; it does not prevent delete/revoke (HC-4/HC-6). UI must say so (FR-P2-HEART-007).
- The private journal (relapse/urge notes) is **never** readable by a sponsor (FR-P2-PRIV-001) — enforced by the owner-only RLS in `schema.sql`.
