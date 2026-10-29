// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  UnlockMachine.swift
//  Pawl — Domain core
//
//  The heart of the loop and the feature that wins the 1am fight (SDS §2.4).
//  Pure reducer: (state, event, now) -> (newState, [effect]). It holds NO iOS
//  dependencies — the app layer (NFCService, ShieldService, TimerScheduler)
//  interprets the emitted effects. This is what makes the loop unit-testable.
//
//  State path: Locked → Reading → CoolingOff → Unshielded → (auto) Locked
//  Tracing: FR-UNLOCK-001..010.
//
//  2.3: the sponsor approval step (Phase 2) was removed with the backend. The physical key
//  is the only gate before the cooling-off, so whoever holds the key is the accountability.
//
//  2.5: ally approvals (docs/18, decision D1 = replace). An ally's signed yes is a second way
//  to pass the gate: key tap OR ally yes, then the same wait. The machine never skips the
//  wait and never lifts the shield on a decision. Checking the signature is not this file's
//  job (see AllyDecisionVerifier.swift); the app layer passes the result in as `valid`.
//

import Foundation

// MARK: - State

public enum UnlockState: Equatable, Sendable {
    case locked
    case reading                          // NFC session open, awaiting a tap (FR-UNLOCK-001)
    case coolingOff(endsAt: Date)         // wait started; shield still up (FR-UNLOCK-003)
    case unshielded(graceEndsAt: Date)    // shield lifted; grace window running (FR-UNLOCK-008)
    /// 2.5: a request is open with the ally. Shield still up. Ends with a decision, expiry,
    /// cancel, or the person reaching for the key instead (FR-ALLY-003).
    case awaitingAlly(requestID: UUID, expiresAt: Date)
}

// MARK: - Events

public enum UnlockEvent: Equatable, Sendable {
    case beginUnlock                      // user initiates (opens NFC session)
    case tap(uidMatches: Bool)            // NFC read completed; UID match result (FR-UNLOCK-002)
    case cancel                           // user backs out (FR-UNLOCK-005)
    case coolingOffEnded                  // DeviceActivity boundary (FR-UNLOCK-007)
    case graceEnded                       // DeviceActivity boundary (FR-UNLOCK-008/009)
    case lockNow                          // 2.4: the person ends the open time early (blocks more)
    case askAlly(requestID: UUID)         // 2.5: the person asks the ally instead of tapping the key
    /// 2.5: the ally answered. `valid` is the app layer's signature, nonce and expiry check
    /// (AllyDecisionVerifier). A yes that is not valid is treated as a no.
    case allyDecision(requestID: UUID, approved: Bool, valid: Bool)
    case allyExpired                      // 2.5: the 30 minute request window passed with no answer
}

// MARK: - Effects (interpreted by the iOS layer)

public enum UnlockEffect: Equatable, Sendable {
    case scheduleCoolingOff(endsAt: Date) // TimerScheduler + persist (FR-UNLOCK-006)
    case liftShield                       // ShieldService clears ManagedSettings (FR-UNLOCK-007)
    case scheduleGrace(endsAt: Date)
    case reapplyShield                    // auto-relock (FR-UNLOCK-008/009)
    case sendAllyRequest(requestID: UUID, expiresAt: Date)   // 2.5: write the Request record
    case withdrawAllyRequest(requestID: UUID)                // 2.5: delete the Request record
}

// MARK: - Reducer

/// Stateless reducer parameterised by the active commitment's durations.
/// Each accepted tap authorises exactly one cooling-off → grace cycle (FR-UNLOCK-010).
public struct UnlockMachine: Sendable {
    public let coolingOff: TimeInterval
    public let grace: TimeInterval

    /// 2.5: how long a request stays open with the ally (docs/18, D4). After this the
    /// request is gone and nothing changed.
    public static let allyRequestWindow: TimeInterval = 30 * 60

    public init(coolingOff: TimeInterval, grace: TimeInterval) {
        // Enforce the floor and ceiling here too (FR-UNLOCK-004). 2.4: the floor is 0 ("No
        // wait"), so this now only stops negative or over-ceiling values.
        self.init(coolingOff: coolingOff, grace: grace, clampFloor: true)
    }

    private init(coolingOff: TimeInterval, grace: TimeInterval, clampFloor: Bool) {
        self.coolingOff = clampFloor ? PawlDefaults.clampCoolingOff(coolingOff) : max(0, coolingOff)
        self.grace = grace
    }

    public init(commitment: Commitment) {
        self.init(coolingOff: commitment.coolingOffSeconds,
                  grace: PawlDefaults.clampGrace(commitment.graceSeconds))
    }

    /// Apply an event. Unhandled (state, event) pairs are no-ops — the shield
    /// never drops as a side effect of an unexpected event (NFR-REL-004).
    public func reduce(_ state: UnlockState, _ event: UnlockEvent, now: Date) -> (UnlockState, [UnlockEffect]) {
        switch (state, event) {

        case (.locked, .beginUnlock):
            return (.reading, [])

        // A valid tap does NOT lift the shield. It starts the wait (FR-UNLOCK-003).
        case (.reading, .tap(let matches)):
            guard matches else { return (.locked, []) }          // mismatch → reject (FR-UNLOCK-002)
            let endsAt = now.addingTimeInterval(coolingOff)
            return (.coolingOff(endsAt: endsAt), [.scheduleCoolingOff(endsAt: endsAt)])

        case (.reading, .cancel):
            return (.locked, [])

        // Cancelling during the wait keeps the shield fully active (FR-UNLOCK-005).
        case (.coolingOff, .cancel):
            return (.locked, [])

        // Only after the full wait does the shield lift, then grace starts (FR-UNLOCK-007/008).
        // 2.4: with "Until I lock it" there is no timer to start. The open state carries
        // `.distantFuture` as its end, and only `lockNow` ends it.
        case (.coolingOff, .coolingOffEnded):
            if PawlDefaults.isUntilLocked(grace) {
                return (.unshielded(graceEndsAt: .distantFuture), [.liftShield])
            }
            let graceEndsAt = now.addingTimeInterval(grace)
            return (.unshielded(graceEndsAt: graceEndsAt), [.liftShield, .scheduleGrace(endsAt: graceEndsAt)])

        // Grace over → auto-relock without user action (FR-UNLOCK-008/009).
        case (.unshielded, .graceEnded):
            return (.locked, [.reapplyShield])

        // 2.4: Lock now. Ending the open time early blocks more, so it is always allowed.
        case (.unshielded, .lockNow):
            return (.locked, [.reapplyShield])

        // MARK: 2.5 ally approvals (FR-ALLY-003..006)

        // Asking the ally opens a request. The shield stays up (FR-ALLY-003).
        case (.locked, .askAlly(let requestID)):
            let expiresAt = now.addingTimeInterval(Self.allyRequestWindow)
            return (.awaitingAlly(requestID: requestID, expiresAt: expiresAt),
                    [.sendAllyRequest(requestID: requestID, expiresAt: expiresAt)])

        // A valid yes for the open request starts the same wait a key tap starts, nothing
        // less (FR-ALLY-004). The request is withdrawn first so the same yes cannot be used
        // twice (FR-ALLY-006). A no, a bad signature, a wrong request ID or a late answer
        // ends the request and leaves everything locked (FR-ALLY-005).
        case (.awaitingAlly(let openID, let expiresAt), .allyDecision(let requestID, let approved, let valid)):
            let accepted = requestID == openID && approved && valid && now <= expiresAt
            guard accepted else { return (.locked, [.withdrawAllyRequest(requestID: openID)]) }
            let endsAt = now.addingTimeInterval(coolingOff)
            return (.coolingOff(endsAt: endsAt),
                    [.withdrawAllyRequest(requestID: openID), .scheduleCoolingOff(endsAt: endsAt)])

        // No answer in time, or the person backs out: locked, request withdrawn (FR-ALLY-005).
        case (.awaitingAlly(let openID, _), .allyExpired),
             (.awaitingAlly(let openID, _), .cancel):
            return (.locked, [.withdrawAllyRequest(requestID: openID)])

        // The physical key always works. Reaching for it while a request is open withdraws
        // the request and opens the key reader (FR-ALLY-007).
        case (.awaitingAlly(let openID, _), .beginUnlock):
            return (.reading, [.withdrawAllyRequest(requestID: openID)])

        default:
            return (state, [])
        }
    }
}
