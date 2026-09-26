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
//  State path (solo):    Locked → Reading → CoolingOff → Unshielded → (auto) Locked
//  State path (sponsor): Locked → Reading → AwaitingApproval → CoolingOff → Unshielded → (auto) Locked
//  Tracing: FR-UNLOCK-001..010; Phase-2 sponsor gate FR-P2-SPON-002..006.
//
//  Phase 2 decision (stacked approval): in sponsor mode a valid key tap does NOT start
//  the cooling-off. It first requests sponsor approval; only once the sponsor APPROVES
//  does the 15-minute cooling-off begin. Deny or no-response timeout → stays locked.
//  The default (requiresSponsorApproval == false) preserves the Phase-1 solo behaviour
//  exactly, so existing call sites and tests are unchanged.
//

import Foundation

// MARK: - State

public enum UnlockState: Equatable, Sendable {
    case locked
    case reading                          // NFC session open, awaiting a tap (FR-UNLOCK-001)
    case awaitingApproval(requestedAt: Date)  // valid key, sponsor decision pending (FR-P2-SPON-002)
    case coolingOff(endsAt: Date)         // wait started; shield still up (FR-UNLOCK-003)
    case unshielded(graceEndsAt: Date)    // shield lifted; grace window running (FR-UNLOCK-008)
}

// MARK: - Events

public enum UnlockEvent: Equatable, Sendable {
    case beginUnlock                      // user initiates (opens NFC session)
    case tap(uidMatches: Bool)            // NFC read completed; UID match result (FR-UNLOCK-002)
    case sponsorDecision(approved: Bool)  // sponsor approved/denied via APNs round-trip (FR-P2-SPON-003/004)
    case approvalTimedOut                 // sponsor did not respond in the window (FR-P2-SPON-005)
    case cancel                           // user backs out (FR-UNLOCK-005)
    case coolingOffEnded                  // DeviceActivity boundary (FR-UNLOCK-007)
    case graceEnded                       // DeviceActivity boundary (FR-UNLOCK-008/009)
}

// MARK: - Effects (interpreted by the iOS layer)

public enum UnlockEffect: Equatable, Sendable {
    case requestSponsorApproval           // create unlock_request server-side, await APNs (FR-P2-SPON-002)
    case cancelSponsorRequest             // user cancelled a pending request; resolve it server-side (FR-P2-SPON-006)
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
    /// When true (sponsor mode), a valid tap requests sponsor approval before any
    /// cooling-off begins (FR-P2-SPON-002). Defaults false → Phase-1 solo behaviour.
    public let requiresSponsorApproval: Bool

    public init(coolingOff: TimeInterval, grace: TimeInterval, requiresSponsorApproval: Bool = false) {
        // Enforce the floor here too, so the machine can never be constructed
        // with a sub-floor cooling-off (FR-UNLOCK-004).
        self.init(coolingOff: coolingOff, grace: grace,
                  requiresSponsorApproval: requiresSponsorApproval, clampFloor: true)
    }

    private init(coolingOff: TimeInterval, grace: TimeInterval,
                 requiresSponsorApproval: Bool, clampFloor: Bool) {
        self.coolingOff = clampFloor ? PawlDefaults.clampCoolingOff(coolingOff) : max(0, coolingOff)
        self.grace = grace
        self.requiresSponsorApproval = requiresSponsorApproval
    }

    public init(commitment: Commitment, requiresSponsorApproval: Bool = false) {
        self.init(coolingOff: commitment.coolingOffSeconds,
                  grace: commitment.graceSeconds,
                  requiresSponsorApproval: requiresSponsorApproval)
    }

    /// Apply an event. Unhandled (state, event) pairs are no-ops — the shield
    /// never drops as a side effect of an unexpected event (NFR-REL-004).
    public func reduce(_ state: UnlockState, _ event: UnlockEvent, now: Date) -> (UnlockState, [UnlockEffect]) {
        switch (state, event) {

        case (.locked, .beginUnlock):
            return (.reading, [])

        // A valid tap does NOT lift the shield. In solo mode it starts the wait
        // (FR-UNLOCK-003). In sponsor mode it requests approval FIRST; the wait only
        // begins once the sponsor approves (stacked approval, FR-P2-SPON-002/003).
        case (.reading, .tap(let matches)):
            guard matches else { return (.locked, []) }          // mismatch → reject (FR-UNLOCK-002)
            if requiresSponsorApproval {
                return (.awaitingApproval(requestedAt: now), [.requestSponsorApproval])
            }
            let endsAt = now.addingTimeInterval(coolingOff)
            return (.coolingOff(endsAt: endsAt), [.scheduleCoolingOff(endsAt: endsAt)])

        case (.reading, .cancel):
            return (.locked, [])

        // Sponsor approved → ONLY NOW does the cooling-off begin (FR-P2-SPON-003).
        // Denied → stays locked, the shield never weakens (FR-P2-SPON-004).
        case (.awaitingApproval, .sponsorDecision(let approved)):
            guard approved else { return (.locked, []) }
            let endsAt = now.addingTimeInterval(coolingOff)
            return (.coolingOff(endsAt: endsAt), [.scheduleCoolingOff(endsAt: endsAt)])

        // No response within the window → fail safe toward locked (FR-P2-SPON-005, HC-4).
        case (.awaitingApproval, .approvalTimedOut):
            return (.locked, [])

        // User backs out while awaiting the sponsor → resolve the pending request
        // server-side and keep the shield up (FR-P2-SPON-006).
        case (.awaitingApproval, .cancel):
            return (.locked, [.cancelSponsorRequest])

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
