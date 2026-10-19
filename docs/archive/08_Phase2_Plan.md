# 08 — Phase 2 Plan & Roadmap (Accountability)

**Date:** 2026-06-22. **Status:** decisions confirmed; design finalized; first slice landed.
This is the map. Requirements live in `01_SRS_Pawl.md` §6.1; design in `02_SDS_Pawl.md`
§3.3 / §4.6–4.8; owner setup in `09_Supabase_APNs_Setup.md`; DDL in `supabase/schema.sql`.

---

## 1. Confirmed decisions

| # | Decision | Choice | Why it matters |
|---|----------|--------|----------------|
| D-P2-1 | Source of truth | **Supabase-first** (canonical cloud SoT). App Group stays runtime-authoritative for the shield; iCloud KVS kept as offline/reinstall cache. Locked-wins reconcile preserved. | Honors "Supabase-first" without letting the shield depend on the network (HC-6) or losing reinstall-proofing (HC-4). |
| D-P2-2 | Auth + linking | **Sign in with Apple**; sponsor linked via single-use, expiring **invite code / deep link** (redeemed server-side). | No passwords; least-privilege linking. |
| D-P2-3 | Approval | **Stacked**: valid tap → sponsor approves → *then* 15-min cooling-off. Deny/timeout (default 60 min) → stays locked. | Strongest friction; fail-safe toward protection. |
| D-P2-4 | Heartbeat | **Opportunistic** (BGTaskScheduler + launch/foreground); tamper alert after **~24h** silence. | Tolerates iOS BG throttling; avoids crying wolf to the sponsor. |

**Accepted tradeoff (D-P2-3):** an asleep/unreachable sponsor means no unlock at all. Mitigation:
a commitment is in sponsor mode **only while a sponsor link is active** (FR-P2-LINK-005); users with
nobody linked yet fall back to the solo cooling-off path, so the app stays usable (D1 solo-first preserved).

## 2. Architecture in one paragraph
Supabase (Postgres + Auth + Edge Functions + RLS) + APNs is added **behind the existing seams**.
The pure `UnlockMachine` gains a sponsor-approval gate; `UnlockViewModel` interprets the new effects;
a `SupabaseCommitmentRepository` sits behind the unchanged `CommitmentRepository` protocol, composed
with the iCloud cache. Extensions are untouched and still read the App Group only. Tamper detection is
**server-only** (silence detection) because there is no OS event for delete/revoke (HC-6).

## 3. Client ↔ server split
- **Client (Swift):** SiwA → Supabase session; APNs registration + token upload; the approval gate in
  the unlock loop; BGTaskScheduler heartbeats; rendering sponsor/tamper notifications. **Shield + timer
  enforcement stays local** (App Group + DeviceActivity), never networked.
- **Server (Supabase):** Auth + RLS; `redeem_invite` / `decide_unlock` / `record_heartbeat` RPCs;
  Edge Functions for APNs fan-out (`unlock-request-notify`, `decide-unlock`) and **scheduled**
  silence detection (`detect-silence` → `detect_silent_clients()`); optional server-side WebAuthn.

## 4. Implementation slices (smallest safe, verify each)

| # | Slice | Depends on | Code hooks | Verify gate |
|---|-------|-----------|------------|-------------|
| 0 | **Approval gate in the pure machine** ✅ *landed* | nothing | `UnlockMachine` (+state/event/effect), `UnlockViewModel`, `UnlockView` | `UnlockMachineTests` green; solo path unchanged; on-device dev approve/deny buttons drive the transition |
| 1 | **Auth (SiwA → Supabase)** | §1–6 of doc 09 | `PawlApp`/`AppModel` (session bootstrap), new `AuthService` | Sign in creates a `profiles` row; signed-out solo loop still shields (FR-P2-AUTH-005) |
| 2 | **Repository swap** | slice 1 | `AppModel.repo` → composite `SupabaseCommitmentRepository` + iCloud cache | Commitment round-trips to Supabase; reinstall still restores from cache; locked-wins holds |
| 3 | **Sponsor linking** | slice 2 | invite UI in Settings/Onboarding, `redeem_invite` RPC | User A invites, User B redeems → A's commitment flips `sponsor_mode = true`; RLS denies cross-user reads |
| 4 | **Unlock approval (wired)** | slices 1–3 | `UnlockViewModel.apply(.requestSponsorApproval)`, APNs round-trip, `decide_unlock` RPC | Real sponsor approve starts cooling-off; deny/timeout stays locked; offline tap stays locked (FR-P2-SPON-009) |
| 5 | **Heartbeat / tamper** | slices 1–2 | BGTask in `PawlApp`, `record_heartbeat`, Edge Fns, cron | Beats land; killing beats for >24h raises a `tamper_alert` + sponsor push |
| 6 | **(optional) Server-side WebAuthn** | slice 1 | `webauthn-verify` Edge Fn, `webauthn_credentials` | Assertion verified server-side with a server challenge (FR-P2-WAUTH-*) |

## 5. Status now
- **Slice 0 landed** (backend-independent): `UnlockMachine` has `.awaitingApproval`,
  `.sponsorDecision(approved:)`, `.approvalTimedOut`, effects `.requestSponsorApproval` /
  `.cancelSponsorRequest`, and a `requiresSponsorApproval` flag (default false = P1 behavior).
  Tests added; `UnlockView`/`UnlockViewModel` updated with dev approve/deny so the flow is
  exercisable on device before the backend exists.
- **Blocked on owner:** slices 1–5 need the Supabase project URL + anon key + APNs key. See doc 09.

## 6. Constraints to keep honest (do not design around)
- **HC-4 / HC-6:** heartbeat *detects* tamper after the fact; nothing here locks delete/revoke — that's
  the Phase-3 sponsor-set Screen Time passcode. Copy must say so (FR-P2-HEART-007, NFR-SEC-001).
- **HC-1:** selection stays opaque tokens; `block_sets.selection_token_data` is never resolved.
- **HC-6 / NFR-REL-002:** extensions take no network; the shield never waits on Supabase.
- **FR-P2-PRIV-001:** relapse/urge notes are owner-only; sponsors never read the private journal.
