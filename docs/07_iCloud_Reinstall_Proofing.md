# Pawl — iCloud reinstall-proofing

Goal: deleting + reinstalling the app must NOT reset the streak or remove protection
(SRS FR-PERSIST-001/002/003). We use **iCloud Key-Value storage** — the right-sized
tool for Phase 1's small data. (CloudKit/Supabase come in Phase 2.)

## How it works
- The commitment, streak, relapse log, and urge log are saved to iCloud KVS
  (`CloudCommitmentRepository`). KVS lives in the user's iCloud, not the app's container,
  so it survives app deletion and syncs back on reinstall.
- The shield selection (which apps/sites) is written to BOTH the App Group (so the
  extensions can read it at runtime) AND iCloud (`SelectionStore`).
- On launch, `RecoveryService.restoreOnLaunch()` pulls the selection back from iCloud if
  the App Group was wiped, and — if there's an active commitment and Screen Time is still
  authorized — re-applies the shield automatically.

## The one Xcode step (no code)
1. Select the **Pawl** target → **Signing & Capabilities** → **+ Capability** → **iCloud**.
2. Under the iCloud capability, tick **Key-value storage**. (You do NOT need CloudKit or a
   container for this.)
3. That's it — Xcode adds the `ubiquity-kvstore` entitlement automatically.

(The extensions don't need iCloud — only the main app reads/writes it.)

## How to test
1. Build & run. In Setup, apply a shield; on Home, build up a streak / log something.
2. **Delete Pawl** from the iPhone.
3. **Reinstall** (run from Xcode again).
4. Open Pawl: the streak/history should come back, and — after granting Screen Time again —
   the shield should re-apply on its own.

## Honest limits (consistent with HC-4)
- Requires the user to be **signed into iCloud**. If they sign out or disable iCloud for
  Pawl, reinstall-proofing is bypassed — an escape hatch we disclose, not hide.
- iCloud sync isn't instant; after reinstall the data may take a few seconds to arrive.
- ⚠️ **Needs device testing:** Screen Time selection tokens are tied to the Family Controls
  authorization. After reinstall + re-authorizing, the restored tokens *should* still shield
  the same apps, but this is an Apple gray area — we'll verify on device and, if tokens don't
  survive re-auth, fall back to having the user re-pick targets (the streak still survives
  regardless). The streak/history reinstall-proofing is solid; the token restore is the part
  to confirm.
