// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  PendingChangeTests.swift
//  2.3 Workstream B, step 0: the shared pending-change store and controller on their own,
//  before any AppModel path uses them. Every test uses a throwaway UserDefaults suite and,
//  except the two timer tests, an injected clock, so nothing sleeps and nothing touches the
//  app's real defaults. Numbers match the test plan. Test 6 (WebCategories and DurationPair
//  round-trips) moves to steps 2 and 3, where those types are added.
//

import XCTest
import FamilyControls
@testable import Pawl

final class PendingChangeTests: XCTestCase {

    private let storeName = "test.pending"
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    /// A fresh, empty UserDefaults suite that is removed when the test ends.
    private func makeDefaults() -> UserDefaults {
        let suite = "PendingChangeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suite) }
        return defaults
    }

    /// A clock the test moves by hand.
    private final class Clock {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private func makeController(_ defaults: UserDefaults, clock: Clock) -> PendingChangeController<Int> {
        PendingChangeController<Int>(store: PendingChangeStore<Int>(name: storeName, defaults: defaults),
                                     now: { clock.now })
    }

    // MARK: Store

    // 1
    func test_store_saveThenLoad_returnsSamePayloadAndEndTime() {
        let store = PendingChangeStore<Int>(name: storeName, defaults: makeDefaults())
        store.save(PendingChange(payload: 42, endsAt: t0))
        let loaded = store.load()
        XCTAssertEqual(loaded?.payload, 42)
        XCTAssertEqual(loaded?.endsAt.timeIntervalSince1970, t0.timeIntervalSince1970)
    }

    // 2
    func test_store_loadWithNothingSaved_returnsNil() {
        let store = PendingChangeStore<Int>(name: storeName, defaults: makeDefaults())
        XCTAssertNil(store.load())
    }

    // 3
    func test_store_clear_removesBothKeys() {
        let defaults = makeDefaults()
        let store = PendingChangeStore<Int>(name: storeName, defaults: defaults)
        store.save(PendingChange(payload: 7, endsAt: t0))
        store.clear()
        XCTAssertNil(defaults.object(forKey: storeName + ".data"))
        XCTAssertNil(defaults.object(forKey: storeName + ".endsAt"))
        XCTAssertNil(store.load())
    }

    // 4
    func test_store_payloadThatFailsToDecode_returnsNil() {
        let defaults = makeDefaults()
        defaults.set(Data("not json".utf8), forKey: storeName + ".data")
        defaults.set(t0.timeIntervalSince1970, forKey: storeName + ".endsAt")
        let store = PendingChangeStore<Int>(name: storeName, defaults: defaults)
        XCTAssertNil(store.load())
    }

    // 5
    func test_store_familyActivitySelection_roundTrips() {
        // Real app and site tokens can't be made in a test, so an empty selection is enough to
        // prove the type encodes and decodes through the store.
        let store = PendingChangeStore<FamilyActivitySelection>(name: storeName, defaults: makeDefaults())
        let selection = FamilyActivitySelection()
        store.save(PendingChange(payload: selection, endsAt: t0))
        XCTAssertEqual(store.load()?.payload, selection)
        XCTAssertEqual(store.load()?.endsAt, t0)
    }

    // MARK: Controller

    // 7
    func test_controller_begin_savesAndSetsPending_withoutApplying() {
        let defaults = makeDefaults()
        let clock = Clock(t0)
        let ctl = makeController(defaults, clock: clock)
        var applied = 0
        ctl.apply = { _ in applied += 1 }

        let ends = t0.addingTimeInterval(900)
        ctl.begin(5, endsAt: ends)

        XCTAssertEqual(ctl.store.load(), PendingChange(payload: 5, endsAt: ends))
        XCTAssertEqual(ctl.pending, PendingChange(payload: 5, endsAt: ends))
        XCTAssertEqual(ctl.endsAt, ends)
        XCTAssertEqual(applied, 0)
        ctl.clear()
    }

    // 8
    func test_controller_restore_futureEndTime_setsPending_doesNotApply() async {
        let defaults = makeDefaults()
        let clock = Clock(t0)
        let ctl = makeController(defaults, clock: clock)
        var applied = 0
        ctl.apply = { _ in applied += 1 }
        let ends = t0.addingTimeInterval(900)
        ctl.store.save(PendingChange(payload: 3, endsAt: ends))

        await ctl.restore()

        XCTAssertEqual(ctl.pending, PendingChange(payload: 3, endsAt: ends))
        XCTAssertEqual(applied, 0)
        ctl.clear()
    }

    // 9
    func test_controller_restore_pastEndTime_appliesOnceThenClears() async {
        let defaults = makeDefaults()
        let clock = Clock(t0)
        let ctl = makeController(defaults, clock: clock)
        var seen: [Int] = []
        ctl.apply = { seen.append($0) }
        ctl.store.save(PendingChange(payload: 9, endsAt: t0.addingTimeInterval(-60)))

        await ctl.restore()

        XCTAssertEqual(seen, [9])
        XCTAssertNil(ctl.store.load())
        XCTAssertNil(ctl.pending)
    }

    // 10
    func test_controller_restore_withNothingSaved_doesNothing() async {
        let ctl = makeController(makeDefaults(), clock: Clock(t0))
        var applied = 0
        ctl.apply = { _ in applied += 1 }

        await ctl.restore()

        XCTAssertNil(ctl.pending)
        XCTAssertEqual(applied, 0)
    }

    // 11
    func test_controller_clearAfterBegin_neverApplies_evenAfterEndTime() async {
        let defaults = makeDefaults()
        let clock = Clock(t0)
        let ctl = makeController(defaults, clock: clock)
        var applied = 0
        ctl.apply = { _ in applied += 1 }
        let ends = t0.addingTimeInterval(900)

        ctl.begin(1, endsAt: ends)
        ctl.clear()
        XCTAssertNil(ctl.store.load())
        XCTAssertNil(ctl.pending)

        clock.now = ends.addingTimeInterval(1)
        await ctl.restore()
        await ctl.commit()
        XCTAssertEqual(applied, 0)
    }

    // 12
    func test_controller_beginTwice_keepsOnlySecond() {
        let defaults = makeDefaults()
        let ctl = makeController(defaults, clock: Clock(t0))
        let first = t0.addingTimeInterval(900)
        let second = t0.addingTimeInterval(1800)

        ctl.begin(1, endsAt: first)
        ctl.begin(2, endsAt: second)

        XCTAssertEqual(ctl.store.load(), PendingChange(payload: 2, endsAt: second))
        XCTAssertEqual(ctl.pending, PendingChange(payload: 2, endsAt: second))
        ctl.clear()
    }

    // 13
    func test_controller_commit_appliesBeforeClearing() async {
        let defaults = makeDefaults()
        let ctl = makeController(defaults, clock: Clock(t0))
        let store = ctl.store
        var payloadSeenInStoreDuringApply: Int?
        ctl.apply = { _ in payloadSeenInStoreDuringApply = store.load()?.payload }
        store.save(PendingChange(payload: 4, endsAt: t0.addingTimeInterval(-1)))

        await ctl.commit()

        XCTAssertEqual(payloadSeenInStoreDuringApply, 4)
        XCTAssertNil(store.load())
    }

    // 14 (real time, kept short)
    func test_controller_timerFires_appliesOnce() async {
        let defaults = makeDefaults()
        let ctl = PendingChangeController<Int>(store: PendingChangeStore<Int>(name: storeName, defaults: defaults))
        let fired = expectation(description: "apply runs when the wait ends")
        var applied = 0
        ctl.apply = { _ in
            applied += 1
            fired.fulfill()
        }

        ctl.begin(8, endsAt: Date().addingTimeInterval(0.2))
        await fulfillment(of: [fired], timeout: 2)

        XCTAssertEqual(applied, 1)
        XCTAssertNil(ctl.store.load())
        XCTAssertNil(ctl.pending)
    }

    // 15 (real time, kept short)
    func test_controller_clearBeforeTimerFires_neverApplies() async {
        let defaults = makeDefaults()
        let ctl = PendingChangeController<Int>(store: PendingChangeStore<Int>(name: storeName, defaults: defaults))
        let fired = expectation(description: "apply must not run")
        fired.isInverted = true
        ctl.apply = { _ in fired.fulfill() }

        ctl.begin(8, endsAt: Date().addingTimeInterval(0.2))
        ctl.clear()
        await fulfillment(of: [fired], timeout: 0.5)

        XCTAssertNil(ctl.store.load())
    }

    // MARK: Same-key continuity (paths with no migration hook)

    // 23
    func test_continuity_selection_readsWhatSelectionChangeStoreWrote() {
        // The exact key names and encoding the 2.2 SelectionChangeStore used, copied here as
        // constants so this test keeps passing now that the class is deleted.
        let oldDataKey = "pawl.pendingSel.data"
        let oldEndKey = "pawl.pendingSel.endsAt"
        let defaults = makeDefaults()
        let selection = FamilyActivitySelection()
        defaults.set(try! JSONEncoder().encode(selection), forKey: oldDataKey)
        defaults.set(t0.timeIntervalSince1970, forKey: oldEndKey)

        let store = PendingChangeStore<FamilyActivitySelection>(name: "pawl.pendingSel", defaults: defaults)
        let loaded = store.load()
        XCTAssertEqual(loaded?.payload, selection)
        XCTAssertEqual(loaded?.endsAt.timeIntervalSince1970, 1_800_000_000)
    }
}
