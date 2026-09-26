# 11 — Phase 3: The Hard Lock (sponsor-set Screen Time passcode)

**Date:** 2026-06-23. **Status:** design + non-functional scaffolding. The headline Phase-3 gap:
the only truly unfakeable tier. Decision D-P3-1 = **sponsor-set Screen Time passcode**, guided
in person at setup (the RG-desk / trusted-supporter model). Builds on HC-4.

---

## 1. Why this exists (the escrow truth, restated)
Phase 1/2 give a strong shield, but two escape hatches remain that Pawl **cannot** close on its
own (HC-4): the user can **delete the app** or **revoke Family Controls authorization** in
Settings. The denyAppRemoval block (FR-P3-HARD-002) stops casual long-press deletion, but a
determined user can still turn off Screen Time. The only thing that closes *both* hatches is a
**Screen Time passcode the user does not control** — and iOS only lets a *person* set that, in
Settings. So the hard lock is inherently a **second-party** mechanism: a sponsor sets it.

## 2. What iOS actually allows (the constraint that shapes everything)
- A third-party app **cannot read** the Screen Time passcode.
- There is **no API** to even query "is a Screen Time passcode set?"
- The app *can* read its own `AuthorizationCenter.shared.authorizationStatus` (`.approved` /
  `.denied` / `.notDetermined`) — but that is the FC authorization, **not** the passcode.
- Therefore Pawl **cannot programmatically confirm** the passcode. Any "passcode verified ✓"
  that claims certainty would be dishonest. We design around this, not against it.

## 3. The flow: **guide → test → attest → monitor**
Pawl never holds or reads the passcode. It runs the ritual and watches for breaches; **iOS
enforces the lock.**

1. **Guide.** In-app, step-by-step, walk the *sponsor* through setting the device Screen Time
   passcode (Settings → Screen Time → Use Screen Time Passcode → pick a code the user never
   sees). Recommend enabling Content & Privacy Restrictions and "Don't Allow" for deleting apps
   while there.
2. **Test in person (the real verification).** Have the sponsor *attempt to undo protection* —
   Settings → Screen Time → try to turn off Pawl's access (or change a restriction). If the
   passcode is set correctly, **iOS prompts for the passcode and blocks it**. The sponsor sees
   the prompt directly. This proves the lock works **without any API** — stronger than a checkbox.
3. **Attest.** The sponsor taps "Passcode set and verified" in the app. This records, on the
   commitment, that the hard lock is active (`hard_lock_active = true`), with a timestamp and the
   sponsor's id. It is an *attestation*, not a Pawl-verified fact — copy says so.
4. **Monitor (the honest backstop).** If the passcode is genuinely set, the user can't revoke FC
   auth or delete the app without it — so the existing tamper signals (heartbeat silence +
   auth-lost, §4.7) should **never** fire. If one does, that's the signal the lock was bypassed
   or never really set, and the sponsor is alerted. So Pawl can't *confirm* the lock up front, but
   it *will* catch it failing later.

## 4. Honest-claims framing (NFR-SEC, HC-4)
- "**iOS enforces this lock; Pawl can't see or change your passcode.**"
- The attestation screen says the sponsor is confirming *they* set and tested it — Pawl is not
  certifying it.
- We never imply Pawl can set, store, recover, or read the passcode. (If the sponsor forgets the
  code, recovery is Apple's process — erase/restore — not Pawl's. Call this out in the guide.)

## 5. Data model (Phase 3 additions — not yet migrated)
On `commitments` (or a small `hard_locks` table):
- `hard_lock_active boolean default false`
- `hard_lock_attested_at timestamptz`
- `hard_lock_attested_by uuid` (the sponsor)
RLS: user + linked sponsor read; set via an RPC the active sponsor calls (least-privilege, like
`decide_unlock`). A sponsor can also mark it removed (which should itself be a logged event).

## 6. SRS requirements (promote from §6.2 stub)
- **FR-P3-HARD-001 [P3]** Guide the sponsor through setting the device Screen Time passcode (the
  app cannot set it) to close the delete/revoke hatches (**HC-4**).
- **FR-P3-HARD-003 [P3]** Provide an in-person **verification test**: prompt the sponsor to attempt
  to disable protection and confirm iOS demands the passcode.
- **FR-P3-HARD-004 [P3]** Record a sponsor **attestation** that the passcode is set + verified
  (`hard_lock_active`), disclosed as an attestation, not a Pawl-verified fact.
- **FR-P3-HARD-005 [P3]** Treat any tamper signal on a hard-locked commitment as a **high-priority**
  alert (the lock may have failed), distinct from the standard silence alert.
- **FR-P3-HARD-006 [P3]** Surface hard-lock status on Home/Settings ("Hard lock: on, set by your
  sponsor on <date>") with the honest framing of §4.

## 7. Alternative on file (D-P3-1, not chosen now)
`.child` Family Sharing enrollment makes `denyAppRemoval` and restrictions truly enforce and be
guardian-controlled — a real OS-level lock — but carries age/Apple-ID eligibility + UX constraints
for adult sponsor relationships. Logged as the fallback if the passcode model proves too fragile
in pilots. See `Competitive_Comparison.md` and SRS §6.2 D-P3-1.

## 8. What's built now (scaffolding)
`HardLockView` (non-functional): the 3-screen guide → in-person test prompt → attestation, plus a
persisted `hardLockAttested` flag (local for now). **No enforcement logic** — it doesn't and can't
set the passcode; it's the UX shell + attestation. Server attestation (RPC + columns), the
high-priority tamper escalation (FR-P3-HARD-005), and status surfacing are the next build steps,
gated on a real partner pilot.
