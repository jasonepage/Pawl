# Build Checkpoint & Smoke Test (Phase 2)

**Owner-run** at the Mac (Xcode + real device). Goal: clean build + green pass on every flow before
new work. Report failures as `step-id + error/symptom`.

---

## How to use this
**Your only job: build the app and send me the red errors.** Open `Pawl.xcodeproj` → pick the
**Pawl** scheme + your iPhone → press **⌘B** → if the left sidebar shows red ❌, copy those
(file + line + message) to me. Sections A/B/C below are reference for *me* when fixing — not a
checklist you work through.

---

## A. Likely-red spots (reference — what I expect to break first)
1. **supabase-swift call shapes** — confirm package version, then verify: `from().select().execute().value`,
   `insert/upsert(row).execute()`, `update().eq().execute()`, `rpc("fn", params:).execute()`,
   `auth.session` / `auth.currentUser`, and the SiwA `signInWithIdToken(credentials:)` initializer name.
2. **`HeartbeatService.registerBackgroundTask()`** — the `nonisolated(unsafe)`→`@MainActor` hop is the
   riskiest Swift-6 spot. Confirm Info.plist `BGTaskSchedulerPermittedIdentifiers` has `…Pawl.heartbeat`.
3. **`SupabaseCommitmentRepository`** — confirm `BlockSet(commitmentID:updatedAt:)` init exists as used.
4. **ManagedSettings web filter** (`PawlShared`) — `.specific/.auto/.none` + `WebDomain(domain:)` should
   compile; if red, it's an SDK case-label change (autocomplete the cases).

## B. Build
Open `Pawl.xcodeproj` → scheme **Pawl** → real iPhone → ⌘⇧K, ⌘B (clear §A), ⌘R.
`APNS_ENV` must match build (`sandbox` dev / `production` TestFlight) or pushes vanish — test via polling first.

## C. Smoke test (tick each; note the FR if it fails)
- [ ] **Solo loop** — fresh onboarding (blocker) → key tap → 15-min cooldown → lift → grace → relock.
- [ ] **Durable** — force-quit during wait → still lifts/relocks on schedule. Block screen has no unlock button.
- [ ] **Signed-out** — solo loop works signed out; sign out never lifts the shield.
- [ ] **Web blocking** — seed domain blocked in Safari + in-app web view; adult-filter toggle (`.auto`) works;
      filter re-applies after relock.
- [ ] **Auth + repo** — SiwA creates a `profiles` row; commitment round-trips to Supabase; delete+reinstall
      restores from iCloud cache offline; locked-wins holds.
- [ ] **Sponsor link** — A invites, B (approver onboarding: sign in + code only) redeems → A flips
      `sponsor_mode`, B gets Approvals tab; B can't read A's journal; revoke → solo, shield stays.
- [ ] **Sponsor unlock (stacked)** — tap → Awaiting-Approval (no cooldown yet); approve → cooldown starts →
      lift → relock; deny → stays locked; 60-min no-response → expires locked; cancel → resolved, shield stays;
      offline tap → does not lift.
- [ ] **Durations / re-pair** — tighten applies instantly; loosen waits out cooldown; re-pair swaps only after cooldown.
- [ ] **Heartbeat / tamper** — beat advances `last_heartbeat_at`; `select detect_silent_clients(interval '1 minute');`
      raises a `tamper_alert` the sponsor sees; revoke Screen Time + relaunch sends auth-lost signal.
- [x] **Spike: `denyAppRemoval` — DONE 2026-06-23, result = WORKS (blocks uninstall).** Under individual auth,
      `= true` removes the "Delete App" option (only "Remove from Home Screen" remains; app stays in Library,
      shield runs). The menu still *shows* "Remove App" — check the actual delete options, not the label.
      Promote to a real always-on feature (SRS FR-P3-HARD-002). Caveat: Settings → Screen Time revoke still
      wipes it (no passcode). Replace the DEBUG spike buttons with the real wiring.

**Known artifact (not a failure):** repeated Start-over leaves multiple `active` commitments → duplicate
tamper alerts. Cleanup is on the list.

When C is green we mark the checkpoint passed (HANDOFF/SRS/SDS) and start the Tier-1 blocklist slice.
