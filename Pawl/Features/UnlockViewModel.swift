// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  UnlockViewModel.swift
//  Pawl — vertical slice
//
//  Drives the unlock loop by feeding events into the pure `UnlockMachine` and
//  interpreting its effects against the real services (SDS §2.4). The physical key
//  is a USB-C / FIDO2 security key via AuthenticationServices (SecurityKeyService).
//
//  ⚠️ Placeholder timing: cooling-off / grace run on a FOREGROUND Task timer here.
//  Fine to demo the flow, but it does NOT survive the app being killed. The durable
//  version schedules these via DeviceActivity in an extension (FR-UNLOCK-006/009,
//  HC-6) — next build step.
//

import Foundation
import FamilyControls

@MainActor
@Observable
public final class UnlockViewModel {
    public private(set) var state: UnlockState = .locked
    /// Base64 of the registered security-key credential ID (the "paired key").
    public private(set) var pairedCredential: String?
    /// When a RE-pair is in its cooling-off: the new key is registered but not yet active.
    public private(set) var pendingKeyEndsAt: Date?
    public private(set) var message: String?
    public private(set) var isBusy = false

    public var isReparing: Bool { pendingKeyEndsAt != nil }

    private var machine: UnlockMachine
    private let security = SecurityKeyService()
    private let shield: ShieldService
    private let selection: FamilyActivitySelection
    private let keyStore: KeyStore
    private var timerTask: Task<Void, Never>?
    private var keyTimerTask: Task<Void, Never>?

    // The active commitment is read fresh at each unlock, so a duration change takes effect
    // without rebuilding the view.
    private let commitmentProvider: () -> Commitment?

    public init(shield: ShieldService,
                selection: FamilyActivitySelection,
                commitmentProvider: @escaping () -> Commitment? = { nil }) {
        self.shield = shield
        self.selection = selection
        self.keyStore = KeyStore()
        self.commitmentProvider = commitmentProvider
        let c = commitmentProvider() ?? Commitment(startedAt: Date(), updatedAt: Date())
        self.machine = UnlockMachine(commitment: c)
        self.pairedCredential = keyStore.load()?.credentialID.base64EncodedString()
        restorePendingKeyChange()   // resume/commit a gated re-pair across launches (FR-NFC-004)
    }

    public var isPaired: Bool { pairedCredential != nil }

    /// Pair the physical security key (FR-NFC-001/002 analog; register the credential).
    ///
    /// First pairing is free (onboarding — there's no friction to bypass yet). RE-pairing an
    /// already-paired key is an unlock-class action (FR-NFC-004, HC-4): the new key is
    /// registered but enters a cooling-off and only becomes active after the wait. The OLD key
    /// stays active until then, so you can't tap "Re-pair", grab a fresh key, and bypass the
    /// escrow. Cancelling keeps your current key.
    public func pairKey() async {
        message = nil
        isBusy = true
        defer { isBusy = false }
        do {
            // Decide free-first-pair vs gated re-pair from a FRESH read, never the cached
            // value: a Keychain that can't be read must not look unpaired (HC-4).
            let pairing = keyStore.state()
            // Use the commitment's real cooling-off, not whatever this screen started with.
            if let c = commitmentProvider() {
                machine = UnlockMachine(commitment: c)
            }
            guard pairing != .unavailable else {
                message = "Pawl can't read its saved key right now. Unlock your phone and try again."
                return
            }
            let newKey = try await security.pairNewKey(displayName: "Pawl key")
            let encoded = newKey.credentialID.base64EncodedString()

            // A first pairing is free only when nothing is being protected yet. With an active
            // commitment and no key (new phone, the key did not transfer), it waits like a re-pair.
            if pairing == .unpaired && commitmentProvider() == nil {
                guard keyStore.save(newKey) else {
                    message = "Couldn't save the key. Nothing changed. Try again."
                    return
                }
                pairedCredential = encoded
                message = "Paired ✓ Now lock the key away: give it to an ally or a timebox, out of reach."
            } else {
                // 2.4: a new key always waits at least the default 15 minutes, even with "No
                // wait". Re-pairing doesn't need the old key, so without this, anyone holding the
                // phone and any security key could make it "the key" and unlock at once.
                let wait = max(machine.coolingOff, PawlDefaults.coolingOffDefault)
                let endsAt = Date().addingTimeInterval(wait)
                guard keyStore.savePending(newKey, endsAt: endsAt) else {
                    message = "Couldn't save the new key. Your current key is unchanged."
                    return
                }
                pendingKeyEndsAt = endsAt
                scheduleKeyCommit(at: endsAt)
                message = "New key registered. It becomes your key \(DurationText.startsIn(waitSeconds: wait)). Your current key still works until then. Cancel to keep your current key."
            }
        } catch {
            message = error.localizedDescription
        }
    }

    /// Cancel an in-progress re-pair; the current key is unchanged (FR-NFC-004).
    public func cancelKeyChange() {
        keyTimerTask?.cancel(); keyTimerTask = nil
        keyStore.clearPending()
        pendingKeyEndsAt = nil
        message = pairedCredential == nil ? "Cancelled. No key was added." : "Cancelled. Your current key is unchanged."
    }

    /// DEV ONLY: skip the re-pair wait.
    public func devSkipKeyWait() { commitPendingKey() }

    /// DEV ONLY: forget the paired key entirely (active + any pending), to retest the first-pair /
    /// unpaired flows. Deliberately NOT a production action — a free removal plus a free first-pair
    /// would let someone swap in an in-reach key and bypass the escrow (HC-4). Re-pair stays gated.
    public func devClearKey() {
        keyTimerTask?.cancel(); keyTimerTask = nil
        keyStore.clearPending()
        keyStore.clear()
        pendingKeyEndsAt = nil
        pairedCredential = nil
        message = "Key removed (dev). Pair again to test the first-pair flow."
    }

    /// Begin an unlock: prove the key is present, then (if it's the same key) start cooling-off.
    public func beginUnlock() async {
        guard pairedCredential != nil, let pairedKey = keyStore.load() else { message = "Pair a key first."; return }
        message = nil
        // Pick up the latest commitment so its durations apply without rebuilding the view.
        machine = UnlockMachine(
            commitment: commitmentProvider() ?? Commitment(startedAt: Date(), updatedAt: Date())
        )
        send(.beginUnlock)
        isBusy = true
        defer { isBusy = false }
        do {
            // FR-UNLOCK-002: same key AND a valid response (challenge, relying party,
            // presence, counter, signature). See WebAuthnVerifier.swift.
            let matches: Bool
            switch try await security.verifyPresence(of: pairedKey) {
            case .verified(let updated):
                // Advance the signature counter, unless a re-pair committed during the tap.
                if keyStore.load()?.credentialID == updated.credentialID { keyStore.save(updated) }
                matches = true
            case .rejected(let reason):
                matches = false
                #if DEBUG
                print("Pawl key check rejected: \(reason)")
                #else
                _ = reason
                #endif
            }
            if !matches { message = "That's not your paired key." }
            send(.tap(uidMatches: matches))
        } catch {
            send(.cancel)
            message = error.localizedDescription
        }
    }

    /// 2.4: Lock now. Ends the open time early (or ends "Until I lock it"). Blocking more is
    /// always allowed, so there is no key and no wait.
    public func lockNow() {
        guard case .unshielded = state else { return }
        timerTask?.cancel(); timerTask = nil
        UnlockScheduler.cancel()      // stop the OS window so it can't lift or relock later
        send(.lockNow)                // reapplyShield: relock with the live selection, clear reminders
    }

    /// 2.4: the line under "Tap to unlock", from the saved wait and open time.
    public var unlockHelpText: String {
        let c = commitmentProvider()
        return DurationText.unlockHelp(waitSeconds: c?.coolingOffSeconds ?? PawlDefaults.coolingOffDefault,
                                       openSeconds: c?.graceSeconds ?? PawlDefaults.graceDefault)
    }

    /// 2.4: apps are open with "Until I lock it", so no timer will lock them.
    public var isOpenUntilLocked: Bool {
        if case .unshielded(let endsAt) = state { return endsAt == .distantFuture }
        return false
    }

    /// Cancel during cooling-off keeps the shield active (FR-UNLOCK-005).
    public func cancel() {
        timerTask?.cancel(); timerTask = nil
        UnlockScheduler.cancel()
        UnlockReminders.cancel()      // 2.3: no "apps open" reminder for an unlock that was cancelled
        send(.cancel)
    }

    /// Reconstruct the displayed state from the real shared phase + window, so reopening
    /// the app after a force-quit shows the truth (not a stale "Locked"). Fixes the
    /// cosmetic gap noted in testing.
    public func syncFromShared() {
        let now = Date()
        switch SharedState.phase() {
        case "unshielded":
            if SharedState.openUntilLocked() {
                state = .unshielded(graceEndsAt: .distantFuture)   // 2.4: open until Lock now
            } else if let end = SharedState.windowEnd(), now < end {
                state = .unshielded(graceEndsAt: end)
                scheduleFire(at: end, event: .graceEnded)
            } else {
                state = .locked
                Task { await UnlockReminders.clearUpcoming() }   // 2.3: the open time is over
            }
        case "cooling":
            if let start = SharedState.windowStart(), now < start {
                // 2.4: finish this unlock with the open time it was scheduled with, not today's
                // setting (a looser timing may have landed during the wait). The OS window and
                // the "Until I lock it" flag were fixed when the wait started.
                let scheduledOpen = SharedState.openUntilLocked()
                    ? PawlDefaults.openUntilLocked
                    : max(PawlDefaults.graceFloor, (SharedState.windowEnd() ?? start).timeIntervalSince(start))
                machine = UnlockMachine(coolingOff: machine.coolingOff, grace: scheduledOpen)
                state = .coolingOff(endsAt: start)
                scheduleFire(at: start, event: .coolingOffEnded)
            } else {
                state = .locked
            }
        default:
            state = .locked
            // 2.3: nothing is unlocking, so drop any leftover reminders (for example from an
            // unlock that ended while Pawl was closed in a way the reminders didn't expect).
            Task { await UnlockReminders.clearUpcoming() }
        }
    }

    /// DEV ONLY: skip the wait to exercise the transition without sitting for 15 min.
    public func devSkipWait() {
        switch state {
        case .coolingOff: send(.coolingOffEnded)
        case .unshielded: send(.graceEnded)
        default: break
        }
    }

    /// The instant the current timed phase ends, for the countdown UI.
    public var phaseEndsAt: Date? {
        switch state {
        case .coolingOff(let endsAt): return endsAt
        case .unshielded(let endsAt): return endsAt == .distantFuture ? nil : endsAt   // 2.4
        default: return nil
        }
    }

    // MARK: - Reducer plumbing

    private func send(_ event: UnlockEvent) {
        let (newState, effects) = machine.reduce(state, event, now: Date())
        state = newState
        effects.forEach(apply)
    }

    private func apply(_ effect: UnlockEffect) {
        switch effect {
        case .scheduleCoolingOff(let endsAt):
            // Drives the in-app countdown UI...
            scheduleFire(at: endsAt, event: .coolingOffEnded)
            // ...AND schedules the OS-owned window that lifts/re-applies the shield even
            // if the app is force-quit (HC-6, FR-UNLOCK-006/009). The PawlMonitor extension
            // handles both ends. The two paths are idempotent if the app stays open.
            // 2.1: if iOS refuses the window, the relock would depend on the app staying open.
            // Stay locked instead (HC-4, HC-6).
            do {
                try UnlockScheduler.scheduleUnlock(coolingOff: machine.coolingOff, grace: machine.grace)
                // 2.3: heads-up reminders before apps open and before they lock again.
                // 2.4: "Until I lock it" has no lock time, so no lock reminders.
                let locksAt: Date? = PawlDefaults.isUntilLocked(machine.grace)
                    ? nil : endsAt.addingTimeInterval(machine.grace)
                Task { await UnlockReminders.schedule(opensAt: endsAt, locksAt: locksAt) }
            } catch {
                timerTask?.cancel(); timerTask = nil
                send(.cancel)
                message = "iOS couldn't schedule the relock, so Pawl stayed locked. Try again."
            }
        case .liftShield:                     shield.lift()
        case .scheduleGrace(let endsAt):
            scheduleFire(at: endsAt, event: .graceEnded)
            // 2.3: keep the lock reminders on the real lock time (same time in a normal unlock).
            // 2.4: not with no wait. The open time starts right after the tap, while schedule()
            // may still be waiting on the permission prompt; moving now would cancel that first
            // set. schedule() already put the lock reminders at this same time.
            if machine.coolingOff > 0 {
                Task { await UnlockReminders.moveLockReminders(to: endsAt) }
            }
        case .reapplyShield:
            // 2.1: relock with the live shared selection (it includes apps added since this
            // screen opened), falling back to the one this screen started with.
            let live = SharedState.loadSelection()
            let liveIsEmpty = live.applicationTokens.isEmpty && live.categoryTokens.isEmpty && live.webDomainTokens.isEmpty
            shield.relock(liveIsEmpty ? selection : live)   // 2.3: the window is over, end it
            // 2.3: apps are locked, so no reminder about an open time may still go off.
            Task { await UnlockReminders.clearUpcoming() }
        }
    }

    private func scheduleFire(at endsAt: Date, event: UnlockEvent) {
        timerTask?.cancel()
        // 2.4: never set a timer for "Until I lock it" (.distantFuture). Its nanoseconds would
        // not fit in a UInt64. Nothing should ask for one; this is the backstop.
        guard endsAt.timeIntervalSinceNow < 7 * 24 * 60 * 60 else { timerTask = nil; return }
        timerTask = Task { [weak self] in
            let delay = endsAt.timeIntervalSinceNow
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            if Task.isCancelled { return }
            self?.send(event)
        }
    }

    // MARK: - Gated re-pair (FR-NFC-004)

    /// On launch, resume an in-progress re-pair — or commit it if the wait already elapsed
    /// while the app was closed (so force-quitting can't skip the cooling-off).
    private func restorePendingKeyChange() {
        guard let pending = keyStore.loadPending() else { return }
        if Date() >= pending.endsAt {
            commitPendingKey()
        } else {
            pendingKeyEndsAt = pending.endsAt
            scheduleKeyCommit(at: pending.endsAt)
        }
    }

    private func scheduleKeyCommit(at endsAt: Date) {
        keyTimerTask?.cancel()
        keyTimerTask = Task { [weak self] in
            let delay = endsAt.timeIntervalSinceNow
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            if Task.isCancelled { return }
            self?.commitPendingKey()
        }
    }

    /// Promote the pending key to active once its cooling-off has elapsed.
    private func commitPendingKey() {
        guard let pending = keyStore.loadPending() else { return }
        guard keyStore.save(pending.key) else { return }   // keep the pending key; retry next launch
        pairedCredential = pending.key.credentialID.base64EncodedString()
        keyStore.clearPending()
        pendingKeyEndsAt = nil
        keyTimerTask?.cancel(); keyTimerTask = nil
        message = "Your new key is now active. Lock it away, out of reach."
    }
}
