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

import Foundation

// MARK: - State

public enum UnlockState: Equatable, Sendable {
    case locked
    case reading                          // NFC session open, awaiting a tap (FR-UNLOCK-001)
    case coolingOff(endsAt: Date)         // wait started; shield still up (FR-UNLOCK-003)
    case unshielded(graceEndsAt: Date)    // shield lifted; grace window running (FR-UNLOCK-008)
}

// MARK: - Events

public enum UnlockEvent: Equatable, Sendable {
    case beginUnlock                      // user initiates (opens NFC session)
    case tap(uidMatches: Bool)            // NFC read completed; UID match result (FR-UNLOCK-002)
    case cancel                           // user backs out (FR-UNLOCK-005)
    case coolingOffEnded                  // DeviceActivity boundary (FR-UNLOCK-007)
    case graceEnded                       // DeviceActivity boundary (FR-UNLOCK-008/009)
}

// MARK: - Effects (interpreted by the iOS layer)

public enum UnlockEffect: Equatable, Sendable {
    case scheduleCoolingOff(endsAt: Date) // TimerScheduler + persist (FR-UNLOCK-006)
    case liftShield                       // ShieldService clears ManagedSettings (FR-UNLOCK-007)
    case scheduleGrace(endsAt: Date)
    case reapplyShield                    // auto-relock (FR-UNLOCK-008/009)
}

// MARK: - Reducer

/// Stateless reducer parameterised by the active commitment's durations.
/// Each accepted tap authorises exactly one cooling-off → grace cycle (FR-UNLOCK-010).
public struct UnlockMachine: Sendable {
    public let coolingOff: TimeInterval
    public let grace: TimeInterval

    public init(coolingOff: TimeInterval, grace: TimeInterval) {
        // Enforce the floor here too, so the machine can never be constructed
        // with a sub-floor cooling-off (FR-UNLOCK-004).
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
        case (.coolingOff, .coolingOffEnded):
            let graceEndsAt = now.addingTimeInterval(grace)
            return (.unshielded(graceEndsAt: graceEndsAt), [.liftShield, .scheduleGrace(endsAt: graceEndsAt)])

        // Grace over → auto-relock without user action (FR-UNLOCK-008/009).
        case (.unshielded, .graceEnded):
            return (.locked, [.reapplyShield])

        default:
            return (state, [])
        }
    }
}
