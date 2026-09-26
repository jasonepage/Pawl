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

    // Slice 4: sponsor mode + the active commitment are read fresh at each unlock, so linking
    // a sponsor takes effect without rebuilding the view. The approval round-trip is delegated
    // to UnlockApprovalService (polling).
    private let commitmentProvider: () -> Commitment?
    private let sponsorModeProvider: () -> Bool
    private let approval: UnlockApprovalService?
    private var activeCommitmentID: UUID?
    private var pendingRequestID: UUID?
    private var approvalTask: Task<Void, Never>?

    public init(shield: ShieldService,
                selection: FamilyActivitySelection,
                commitmentProvider: @escaping () -> Commitment? = { nil },
                sponsorModeProvider: @escaping () -> Bool = { false },
                approval: UnlockApprovalService? = nil) {
        self.shield = shield
        self.selection = selection
        self.keyStore = KeyStore()
        self.commitmentProvider = commitmentProvider
        self.sponsorModeProvider = sponsorModeProvider
        self.approval = approval
        let c = commitmentProvider() ?? Commitment(startedAt: Date(), updatedAt: Date())
        self.machine = UnlockMachine(commitment: c, requiresSponsorApproval: sponsorModeProvider())
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
                machine = UnlockMachine(commitment: c, requiresSponsorApproval: sponsorModeProvider())
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
                message = "Paired ✓ Now lock the key away — give it to a sponsor or a timebox, out of reach."
            } else {
                let endsAt = Date().addingTimeInterval(machine.coolingOff)
                guard keyStore.savePending(newKey, endsAt: endsAt) else {
                    message = "Couldn't save the new key. Your current key is unchanged."
                    return
                }
                pendingKeyEndsAt = endsAt
                scheduleKeyCommit(at: endsAt)
                let mins = Int(machine.coolingOff / 60)
                message = "New key registered. It becomes your key in \(mins) min — your current key still works until then. Cancel to keep your current key."
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
        // Pick up the latest sponsor mode + commitment so linking a sponsor takes effect
        // without rebuilding the view (FR-P2-LINK-005, FR-P2-SPON-002).
        let commitment = commitmentProvider()
        activeCommitmentID = commitment?.id
        machine = UnlockMachine(
            commitment: commitment ?? Commitment(startedAt: Date(), updatedAt: Date()),
            requiresSponsorApproval: sponsorModeProvider()
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
            if matches { Feedback.keyRecognized() }
            else { Feedback.warning(); message = "That's not your paired key." }
            send(.tap(uidMatches: matches))
        } catch {
            send(.cancel)
            message = error.localizedDescription
        }
    }

    /// Cancel during cooling-off keeps the shield active (FR-UNLOCK-005).
    public func cancel() {
        timerTask?.cancel(); timerTask = nil
        UnlockScheduler.cancel()
        send(.cancel)
    }

    /// Reconstruct the displayed state from the real shared phase + window, so reopening
    /// the app after a force-quit shows the truth (not a stale "Locked"). Fixes the
    /// cosmetic gap noted in testing.
    public func syncFromShared() {
        let now = Date()
        switch SharedState.phase() {
        case "unshielded":
            if let end = SharedState.windowEnd(), now < end {
                state = .unshielded(graceEndsAt: end)
                scheduleFire(at: end, event: .graceEnded)
            } else {
                state = .locked
            }
        case "cooling":
            if let start = SharedState.windowStart(), now < start {
                state = .coolingOff(endsAt: start)
                scheduleFire(at: start, event: .coolingOffEnded)
            } else {
                state = .locked
            }
        default:
            state = .locked
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

    /// DEV ONLY: stand in for the sponsor's APNs decision until the backend slice lands.
    /// Approve → cooling-off begins; deny → stays locked (FR-P2-SPON-003/004).
    public func devSimulateSponsor(approved: Bool) {
        send(.sponsorDecision(approved: approved))
    }

    /// The instant the current timed phase ends, for the countdown UI.
    public var phaseEndsAt: Date? {
        switch state {
        case .coolingOff(let endsAt): return endsAt
        case .unshielded(let endsAt): return endsAt
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
        case .requestSponsorApproval:
            message = "Sent to your sponsor for approval…"
            requestSponsorApproval()
        case .cancelSponsorRequest:
            cancelSponsorApproval()
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
            } catch {
                timerTask?.cancel(); timerTask = nil
                send(.cancel)
                message = "iOS couldn't schedule the relock, so Pawl stayed locked. Try again."
            }
        case .liftShield:                     shield.lift(); Feedback.shieldLifted()   // understated — not a reward
        case .scheduleGrace(let endsAt):      scheduleFire(at: endsAt, event: .graceEnded)
        case .reapplyShield:
            // 2.1: relock with the live shared selection (it includes apps added since this
            // screen opened), falling back to the one this screen started with.
            let live = SharedState.loadSelection()
            let liveIsEmpty = live.applicationTokens.isEmpty && live.categoryTokens.isEmpty && live.webDomainTokens.isEmpty
            shield.apply(liveIsEmpty ? selection : live)
            Feedback.relock()
        }
    }

    private func scheduleFire(at endsAt: Date, event: UnlockEvent) {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            let delay = endsAt.timeIntervalSinceNow
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            if Task.isCancelled { return }
            self?.send(event)
        }
    }

    // MARK: - Sponsor approval round-trip (FR-P2-SPON-002..006)

    /// Create the unlock_request and poll for the sponsor's decision, then feed it back into
    /// the pure machine. Fail-safe: any error / no service → stay locked (HC-4).
    private func requestSponsorApproval() {
        guard let approval, let commitmentID = activeCommitmentID else {
            message = "Couldn't reach sponsor approval — staying locked."
            send(.approvalTimedOut)
            return
        }
        approvalTask?.cancel()
        approvalTask = Task { [weak self] in
            guard let self else { return }
            do {
                let requestID = try await approval.createRequest(commitmentID: commitmentID)
                self.pendingRequestID = requestID
                let decision = await approval.pollDecision(requestID: requestID)
                if Task.isCancelled { return }
                switch decision {
                case .approved: self.send(.sponsorDecision(approved: true))
                case .denied:   self.send(.sponsorDecision(approved: false))
                case .expired, .failed: self.send(.approvalTimedOut)
                }
                self.pendingRequestID = nil
            } catch {
                if !Task.isCancelled {
                    self.message = error.localizedDescription
                    self.send(.approvalTimedOut)
                }
            }
        }
    }

    private func cancelSponsorApproval() {
        approvalTask?.cancel(); approvalTask = nil
        if let approval, let requestID = pendingRequestID {
            Task { try? await approval.cancel(requestID: requestID) }
        }
        pendingRequestID = nil
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
