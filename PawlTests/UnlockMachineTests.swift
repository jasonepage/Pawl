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

    // FR-UNLOCK-004: cooling-off is clamped to its floor and ceiling. 2.4: the floor is 0
    // ("No wait"), so a 1 minute wait is kept and only negative values are raised.
    func test_coolingOffFloorEnforced() {
        XCTAssertEqual(UnlockMachine(coolingOff: 60, grace: 900).coolingOff, 60)
        XCTAssertEqual(UnlockMachine(coolingOff: -5, grace: 900).coolingOff, PawlDefaults.coolingOffFloor)
        XCTAssertEqual(UnlockMachine(coolingOff: 48 * 3600, grace: 900).coolingOff, PawlDefaults.coolingOffCeiling)
    }

    // 2.3: the ally (sponsor) approval step was removed. A valid tap always goes straight to
    // the cooling-off; the key is the only gate before the wait.
    func test_validTap_goesStraightToCoolingOff() {
        let (state, effects) = machine().reduce(.reading, .tap(uidMatches: true), now: t0)
        XCTAssertEqual(state, .coolingOff(endsAt: t0.addingTimeInterval(900)))
        XCTAssertEqual(effects, [.scheduleCoolingOff(endsAt: t0.addingTimeInterval(900))])
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
