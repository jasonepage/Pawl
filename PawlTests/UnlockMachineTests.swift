// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  UnlockMachineTests.swift
//  PawlTests — domain core
//
//  Executable spec for the unlock loop. Each test names the requirement it pins.
//  To run: add a "Unit Testing Bundle" target named PawlTests in Xcode (File ▸ New ▸
//  Target ▸ Unit Testing Bundle), with @testable import Pawl.
//

import XCTest
@testable import Pawl

final class UnlockMachineTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_000_000)
    private func machine(cool: TimeInterval = 900, grace: TimeInterval = 900) -> UnlockMachine {
        UnlockMachine(coolingOff: cool, grace: grace)
    }

    // FR-UNLOCK-001: begin opens the reading state.
    func test_begin_movesToReading() {
        let (state, effects) = machine().reduce(.locked, .beginUnlock, now: t0)
        XCTAssertEqual(state, .reading)
        XCTAssertTrue(effects.isEmpty)
    }

    // FR-UNLOCK-003: a valid tap starts the wait and does NOT lift the shield.
    func test_validTap_startsCoolingOff_doesNotLift() {
        let (state, effects) = machine().reduce(.reading, .tap(uidMatches: true), now: t0)
        let endsAt = t0.addingTimeInterval(900)
        XCTAssertEqual(state, .coolingOff(endsAt: endsAt))
        XCTAssertEqual(effects, [.scheduleCoolingOff(endsAt: endsAt)])
        XCTAssertFalse(effects.contains(.liftShield)) // never lifts on tap
    }

    // FR-UNLOCK-002: a UID mismatch is rejected; shield stays.
    func test_mismatchTap_rejected() {
        let (state, effects) = machine().reduce(.reading, .tap(uidMatches: false), now: t0)
        XCTAssertEqual(state, .locked)
        XCTAssertTrue(effects.isEmpty)
    }

    // FR-UNLOCK-005: cancelling during cooling-off keeps the shield active, lifts nothing.
    func test_cancelDuringCoolingOff_staysLocked() {
        let cooling = UnlockState.coolingOff(endsAt: t0.addingTimeInterval(900))
        let (state, effects) = machine().reduce(cooling, .cancel, now: t0.addingTimeInterval(60))
        XCTAssertEqual(state, .locked)
        XCTAssertTrue(effects.isEmpty)
    }

    // FR-UNLOCK-007/008: only after the wait does the shield lift, then grace starts.
    func test_coolingOffEnded_liftsAndStartsGrace() {
        let cooling = UnlockState.coolingOff(endsAt: t0.addingTimeInterval(900))
        let now = t0.addingTimeInterval(900)
        let (state, effects) = machine().reduce(cooling, .coolingOffEnded, now: now)
        let graceEnds = now.addingTimeInterval(900)
        XCTAssertEqual(state, .unshielded(graceEndsAt: graceEnds))
        XCTAssertEqual(effects, [.liftShield, .scheduleGrace(endsAt: graceEnds)])
    }

    // FR-UNLOCK-008/009: grace expiry auto-relocks without user action.
    func test_graceEnded_autoRelocks() {
        let unshielded = UnlockState.unshielded(graceEndsAt: t0.addingTimeInterval(900))
        let (state, effects) = machine().reduce(unshielded, .graceEnded, now: t0.addingTimeInterval(900))
        XCTAssertEqual(state, .locked)
        XCTAssertEqual(effects, [.reapplyShield])
    }

    // FR-UNLOCK-010: a tap arriving outside .reading is a no-op (one tap = one cycle).
    func test_strayTap_isNoOp() {
        let unshielded = UnlockState.unshielded(graceEndsAt: t0.addingTimeInterval(900))
        let (state, effects) = machine().reduce(unshielded, .tap(uidMatches: true), now: t0)
        XCTAssertEqual(state, unshielded)
        XCTAssertTrue(effects.isEmpty)
    }

    // FR-UNLOCK-004: cooling-off can never be constructed below the 15-min floor.
    func test_coolingOffFloorEnforced() {
        let m = UnlockMachine(coolingOff: 60, grace: 900) // request 1 min
        XCTAssertEqual(m.coolingOff, PawlDefaults.coolingOffFloor)
    }

    // MARK: - Phase 2: sponsor approval gate (FR-P2-SPON-002..006)

    private func sponsorMachine(cool: TimeInterval = 900, grace: TimeInterval = 900) -> UnlockMachine {
        UnlockMachine(coolingOff: cool, grace: grace, requiresSponsorApproval: true)
    }

    // FR-P2-SPON-002: in sponsor mode a valid tap requests approval and does NOT start
    // the wait or lift the shield.
    func test_sponsor_validTap_awaitsApproval_doesNotStartWait() {
        let (state, effects) = sponsorMachine().reduce(.reading, .tap(uidMatches: true), now: t0)
        XCTAssertEqual(state, .awaitingApproval(requestedAt: t0))
        XCTAssertEqual(effects, [.requestSponsorApproval])
        XCTAssertFalse(effects.contains(.scheduleCoolingOff(endsAt: t0.addingTimeInterval(900))))
        XCTAssertFalse(effects.contains(.liftShield))
    }

    // FR-P2-SPON-002: a UID mismatch is still rejected before any approval is requested.
    func test_sponsor_mismatchTap_rejected_noApprovalRequested() {
        let (state, effects) = sponsorMachine().reduce(.reading, .tap(uidMatches: false), now: t0)
        XCTAssertEqual(state, .locked)
        XCTAssertTrue(effects.isEmpty)
    }

    // FR-P2-SPON-003: approval STACKS — cooling-off begins only once the sponsor approves.
    func test_sponsor_approval_startsCoolingOff() {
        let awaiting = UnlockState.awaitingApproval(requestedAt: t0)
        let now = t0.addingTimeInterval(120) // sponsor replies 2 min later
        let (state, effects) = sponsorMachine().reduce(awaiting, .sponsorDecision(approved: true), now: now)
        let endsAt = now.addingTimeInterval(900)
        XCTAssertEqual(state, .coolingOff(endsAt: endsAt))
        XCTAssertEqual(effects, [.scheduleCoolingOff(endsAt: endsAt)])
    }

    // FR-P2-SPON-004: a denial keeps the shield fully up; no wait, no lift.
    func test_sponsor_denial_staysLocked() {
        let awaiting = UnlockState.awaitingApproval(requestedAt: t0)
        let (state, effects) = sponsorMachine().reduce(awaiting, .sponsorDecision(approved: false), now: t0.addingTimeInterval(60))
        XCTAssertEqual(state, .locked)
        XCTAssertTrue(effects.isEmpty)
    }

    // FR-P2-SPON-005: no sponsor response → fail safe toward locked.
    func test_sponsor_timeout_staysLocked() {
        let awaiting = UnlockState.awaitingApproval(requestedAt: t0)
        let (state, effects) = sponsorMachine().reduce(awaiting, .approvalTimedOut, now: t0.addingTimeInterval(3600))
        XCTAssertEqual(state, .locked)
        XCTAssertTrue(effects.isEmpty)
    }

    // FR-P2-SPON-006: user cancels while awaiting → resolve the pending request, stay locked.
    func test_sponsor_cancelWhileAwaiting_resolvesRequest() {
        let awaiting = UnlockState.awaitingApproval(requestedAt: t0)
        let (state, effects) = sponsorMachine().reduce(awaiting, .cancel, now: t0.addingTimeInterval(30))
        XCTAssertEqual(state, .locked)
        XCTAssertEqual(effects, [.cancelSponsorRequest])
    }

    // A sponsor decision arriving outside .awaitingApproval is a no-op (never weakens the shield).
    func test_sponsor_strayDecision_isNoOp() {
        let cooling = UnlockState.coolingOff(endsAt: t0.addingTimeInterval(900))
        let (state, effects) = sponsorMachine().reduce(cooling, .sponsorDecision(approved: true), now: t0)
        XCTAssertEqual(state, cooling)
        XCTAssertTrue(effects.isEmpty)
    }

    // Regression: the default machine (solo) is unchanged — a valid tap still goes straight
    // to cooling-off with no approval request.
    func test_solo_validTap_unchanged_noApprovalRequest() {
        let (state, effects) = machine().reduce(.reading, .tap(uidMatches: true), now: t0)
        XCTAssertEqual(state, .coolingOff(endsAt: t0.addingTimeInterval(900)))
        XCTAssertEqual(effects, [.scheduleCoolingOff(endsAt: t0.addingTimeInterval(900))])
        XCTAssertFalse(effects.contains(.requestSponsorApproval))
    }
}

final class StreakAndReconcileTests: XCTestCase {

    func test_cleanDays_countsFromLastRelapse() {
        let cal = Calendar(identifier: .gregorian)
        let start = Date(timeIntervalSince1970: 0)
        let relapse = start.addingTimeInterval(10 * 86_400)
        let now = start.addingTimeInterval(13 * 86_400)
        XCTAssertEqual(Streak.cleanDays(commitmentStart: start, lastRelapse: relapse, now: now, calendar: cal), 3)
    }

    func test_cleanDays_noRelapse_countsFromStart() {
        let cal = Calendar(identifier: .gregorian)
        let start = Date(timeIntervalSince1970: 0)
        let now = start.addingTimeInterval(5 * 86_400)
        XCTAssertEqual(Streak.cleanDays(commitmentStart: start, lastRelapse: nil, now: now, calendar: cal), 5)
    }

    // FR-PERSIST-003: a stale unlocked remote must not override a local active shield.
    func test_reconcile_lockedWins() {
        let now = Date(timeIntervalSince1970: 1000)
        func snap(_ status: CommitmentStatus, updated: Date) -> CommitmentSnapshot {
            let c = Commitment(status: status, startedAt: now, updatedAt: updated)
            return CommitmentSnapshot(commitment: c, blockSet: BlockSet(commitmentID: c.id, updatedAt: updated), keyPairing: nil)
        }
        let localActive = snap(.active, updated: now)                     // older
        let remoteInactiveNewer = snap(.inactive, updated: now.addingTimeInterval(100)) // newer but unlocked
        let merged = CommitmentReconciler.merge(local: localActive, remote: remoteInactiveNewer)
        XCTAssertEqual(merged?.commitment.status, .active)
    }
}
