// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  AllyUnlockMachineTests.swift
//  PawlTests: domain core
//
//  2.5 ally approvals, step 0 of docs/18. These pin the one rule that matters: an ally's yes
//  is another way to START the wait, never a way past it. The shield never drops here.
//  The nine original UnlockMachineTests must still pass unchanged.
//

import XCTest
@testable import Pawl

final class AllyUnlockMachineTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_000_000)
    private let requestID = UUID()
    private func machine(cool: TimeInterval = 900) -> UnlockMachine {
        UnlockMachine(coolingOff: cool, grace: 900)
    }
    private var open: UnlockState {
        .awaitingAlly(requestID: requestID, expiresAt: t0.addingTimeInterval(UnlockMachine.allyRequestWindow))
    }

    // FR-ALLY-003: asking opens a request for 30 minutes. The shield stays up.
    func test_askAlly_opensRequest_doesNotLift() {
        let (state, effects) = machine().reduce(.locked, .askAlly(requestID: requestID), now: t0)
        let expiresAt = t0.addingTimeInterval(30 * 60)
        XCTAssertEqual(state, .awaitingAlly(requestID: requestID, expiresAt: expiresAt))
        XCTAssertEqual(effects, [.sendAllyRequest(requestID: requestID, expiresAt: expiresAt)])
        XCTAssertFalse(effects.contains(.liftShield))
    }

    // FR-ALLY-004: a valid yes starts the same wait a key tap starts. Nothing is lifted.
    func test_validYes_startsCoolingOff_sameAsKeyTap() {
        let now = t0.addingTimeInterval(120)
        let (state, effects) = machine().reduce(open, .allyDecision(requestID: requestID, approved: true, valid: true), now: now)
        let endsAt = now.addingTimeInterval(900)
        XCTAssertEqual(state, .coolingOff(endsAt: endsAt))
        XCTAssertEqual(effects, [.withdrawAllyRequest(requestID: requestID), .scheduleCoolingOff(endsAt: endsAt)])
        XCTAssertFalse(effects.contains(.liftShield))

        // The same wait a key tap would give.
        let (keyState, _) = machine().reduce(.reading, .tap(uidMatches: true), now: now)
        XCTAssertEqual(keyState, state)
    }

    // FR-ALLY-005: "Not now" leaves everything locked and withdraws the request.
    func test_no_staysLocked() {
        let (state, effects) = machine().reduce(open, .allyDecision(requestID: requestID, approved: false, valid: true), now: t0)
        XCTAssertEqual(state, .locked)
        XCTAssertEqual(effects, [.withdrawAllyRequest(requestID: requestID)])
    }

    // FR-ALLY-005: a yes whose signature did not check out is a no.
    func test_invalidYes_isANo() {
        let (state, effects) = machine().reduce(open, .allyDecision(requestID: requestID, approved: true, valid: false), now: t0)
        XCTAssertEqual(state, .locked)
        XCTAssertEqual(effects, [.withdrawAllyRequest(requestID: requestID)])
    }

    // FR-ALLY-005: a yes for some other request does not count.
    func test_yesForWrongRequest_isANo() {
        let (state, effects) = machine().reduce(open, .allyDecision(requestID: UUID(), approved: true, valid: true), now: t0)
        XCTAssertEqual(state, .locked)
        XCTAssertEqual(effects, [.withdrawAllyRequest(requestID: requestID)])
    }

    // FR-ALLY-005: a yes that arrives after the 30 minutes is a no.
    func test_lateYes_isANo() {
        let late = t0.addingTimeInterval(30 * 60 + 1)
        let (state, effects) = machine().reduce(open, .allyDecision(requestID: requestID, approved: true, valid: true), now: late)
        XCTAssertEqual(state, .locked)
        XCTAssertEqual(effects, [.withdrawAllyRequest(requestID: requestID)])
    }

    // A yes at the exact expiry second still counts.
    func test_yesAtExpiry_counts() {
        let edge = t0.addingTimeInterval(30 * 60)
        let (state, _) = machine().reduce(open, .allyDecision(requestID: requestID, approved: true, valid: true), now: edge)
        XCTAssertEqual(state, .coolingOff(endsAt: edge.addingTimeInterval(900)))
    }

    // FR-ALLY-005: expiry and cancel both go back to locked with the request withdrawn.
    func test_expiredOrCancelled_staysLocked() {
        for event in [UnlockEvent.allyExpired, .cancel] {
            let (state, effects) = machine().reduce(open, event, now: t0)
            XCTAssertEqual(state, .locked)
            XCTAssertEqual(effects, [.withdrawAllyRequest(requestID: requestID)])
        }
    }

    // FR-ALLY-006: one request is good for one wait. After the yes is used the request is
    // gone, so the same yes arriving again is a stray event and changes nothing.
    func test_replayedYes_isNoOp() {
        let (afterYes, _) = machine().reduce(open, .allyDecision(requestID: requestID, approved: true, valid: true), now: t0)
        let (state, effects) = machine().reduce(afterYes, .allyDecision(requestID: requestID, approved: true, valid: true), now: t0)
        XCTAssertEqual(state, afterYes)
        XCTAssertTrue(effects.isEmpty)
    }

    // FR-ALLY-007: the physical key always works. Reaching for it withdraws the request.
    func test_keyDuringRequest_withdrawsAndReads() {
        let (state, effects) = machine().reduce(open, .beginUnlock, now: t0)
        XCTAssertEqual(state, .reading)
        XCTAssertEqual(effects, [.withdrawAllyRequest(requestID: requestID)])
    }

    // Asking is only possible from locked. During the wait, while open, or while the key is
    // being read, it is a no-op, so an ally yes can never stack a second cycle (FR-UNLOCK-010).
    func test_askAlly_outsideLocked_isNoOp() {
        let soon = t0.addingTimeInterval(900)
        for state in [UnlockState.reading, .coolingOff(endsAt: soon), .unshielded(graceEndsAt: soon), open] {
            let (next, effects) = machine().reduce(state, .askAlly(requestID: UUID()), now: t0)
            XCTAssertEqual(next, state)
            XCTAssertTrue(effects.isEmpty)
        }
    }

    // A decision arriving when no request is open changes nothing. The shield never drops as a
    // side effect of an unexpected event (NFR-REL-004).
    func test_strayDecision_isNoOp() {
        let soon = t0.addingTimeInterval(900)
        for state in [UnlockState.locked, .reading, .coolingOff(endsAt: soon), .unshielded(graceEndsAt: soon)] {
            let (next, effects) = machine().reduce(state, .allyDecision(requestID: requestID, approved: true, valid: true), now: t0)
            XCTAssertEqual(next, state)
            XCTAssertTrue(effects.isEmpty)
            let (next2, effects2) = machine().reduce(state, .allyExpired, now: t0)
            XCTAssertEqual(next2, state)
            XCTAssertTrue(effects2.isEmpty)
        }
    }

    // 2.4 "No wait" through an ally: the wait ends at once, exactly as it does with the key.
    // It is still the cooling-off path, so the app layer is the one that lifts the shield.
    func test_noWait_viaAlly_matchesKey() {
        let (state, effects) = machine(cool: 0).reduce(open, .allyDecision(requestID: requestID, approved: true, valid: true), now: t0)
        XCTAssertEqual(state, .coolingOff(endsAt: t0))
        XCTAssertEqual(effects, [.withdrawAllyRequest(requestID: requestID), .scheduleCoolingOff(endsAt: t0)])
    }
}
