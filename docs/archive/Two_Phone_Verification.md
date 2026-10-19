# Two-Phone Verification — Sponsor Approval + Tamper

Owner-run on two real devices. **A = blocker** (the person quitting), **B = sponsor/approver**.
Both signed in (Sign in with Apple). For push to fire, `APNS_ENV` must match the build (sandbox =
Xcode dev, production = TestFlight); **polling works regardless**, so if push is silent, the Approvals
tab still updates within ~5s.

Code audit (2026-06-23) confirmed the logic is correct and fails safe to **locked** on every
non-approval path. This script is to confirm it on-device end to end.

## Setup
1. **A** (blocker): onboard, pair key, activate. Settings → "Invite a sponsor" → get the code.
2. **B** (approver): onboard as approver (sign in + enter A's code) — or Settings → "Are you a
   sponsor?" → enter code. Confirm B shows "Linked ✓" and an **Approvals** tab appears.
3. On **A**, confirm sponsor mode is active (an active link exists). A's next unlock now needs B.

## Approve (happy path)
1. A: Unlock tab → tap key. Expect **"Sent to your sponsor for approval…"**, shield stays on, **no
   countdown yet**.
2. B: Approvals tab → the request appears (≤5s) → tap **Approve**.
3. A: within ~5s the **15-min cooling-off starts** (countdown shows). ✅ approval *stacks before* the wait.
4. Let it run (or DEBUG skip): cooling-off → shield lifts → grace → **relock** (feel the click). ✅

## Deny
1. A: tap key → awaiting approval.
2. B: **Deny**.
3. A: returns to **Locked**, shield untouched, no countdown. ✅

## Timeout (fail-safe)
1. A: tap key → awaiting approval. B does **nothing**.
2. The request expires server-side at 60 min; A stays **Locked**. (To check fast without waiting an
   hour, just confirm A stays locked and the shield holds — the deadline math is covered by the audit.) ✅

## Cancel
1. A: tap key → awaiting approval → tap **Cancel** (the in-app cancel).
2. A: shield stays on, returns to Locked. B's pending request disappears (≤5s). ✅

## Offline tap (fail-safe)
1. A: enable Airplane Mode → tap key.
2. A: does **not** lift; reports it can't reach approval; stays **Locked**. ✅ (Turn Wi-Fi back on after.)

## Tamper — silence (sponsor alert)
The real threshold is 24h. Force it now from the SQL editor:
```sql
select public.detect_silent_clients(interval '1 minute');
```
1. Run it. B: Approvals tab → **"⚠️ App went silent — may be deleted"** appears under Protection
   alerts (≤5s via polling; push too if APNS_ENV matches). ✅
2. (Optional push test) Invoke the `detect-silence` Edge Function and confirm B gets the APNs banner.

## Tamper — auth lost
1. A: Settings app → Screen Time → turn off Pawl's access (revoke authorization).
2. A: relaunch Pawl. On launch it reports auth-lost.
3. B: Approvals tab → **"⚠️ Screen Time was turned off"** appears. ✅
4. Re-grant Screen Time on A afterward.

---

## Audit findings (for the record)
- **FIXED:** `detect_silent_clients` now `select distinct` — a user with duplicate active commitments
  (dev re-onboarding artifact) no longer gets duplicate silence alerts. **Action: re-run the updated
  `detect_silent_clients` function from `schema.sql` in the SQL editor** so the live DB picks up the fix.
- **Note (hygiene, not a bug):** nothing flips an un-decided `unlock_request` to `status='expired'` at
  its `expires_at`; rows stay `pending`. Harmless (client fails safe locally; `decide_unlock` rejects
  late decisions), but a future cleanup could mark them expired.
- **Note (UX follow-up):** if A force-quits the app *while awaiting approval*, the poll doesn't resume
  on relaunch — a later approval is ignored and A must re-tap. Stays locked (safe), just not auto-resumed.
  Candidate follow-up: resume a pending unlock_request on launch.
- **Note (cosmetic):** the comment at the bottom of `schema.sql` names old Edge Functions
  (`unlock-request-notify`/`decide-unlock`); the real ones are `notify-sponsor`/`notify-user`/`detect-silence`.
