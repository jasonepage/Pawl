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

    // 6
    func test_store_payloadTypes_roundTripEveryCombination() {
        let defaults = makeDefaults()
        let cats = PendingChangeStore<WebCategories>(name: storeName + ".cats", defaults: defaults)
        for gambling in [false, true] {
            for adult in [false, true] {
                let value = WebCategories(gambling: gambling, adult: adult)
                cats.save(PendingChange(payload: value, endsAt: t0))
                XCTAssertEqual(cats.load()?.payload, value)
                XCTAssertEqual(cats.load()?.endsAt, t0)
            }
        }
        let durations = PendingChangeStore<DurationPair>(name: storeName + ".dur", defaults: defaults)
        for cooldown in [60.0, 900.0, 3600.0] {
            for grace in [0.0, 300.0, 1800.0] {
                let value = DurationPair(cooldown: cooldown, grace: grace)
                durations.save(PendingChange(payload: value, endsAt: t0))
                XCTAssertEqual(durations.load()?.payload, value)
                XCTAssertEqual(durations.load()?.endsAt, t0)
            }
        }
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

    // MARK: Category migration (old pawl.pendingCat.* keys)

    // The 2.2 key names, copied here as constants so these tests keep pinning them.
    private let oldCatGambling = "pawl.pendingCat.gambling"
    private let oldCatAdult = "pawl.pendingCat.adult"
    private let oldCatEnd = "pawl.pendingCat.endsAt"
    private let newCatData = "pawl.pendingCategories.data"
    private let newCatEnd = "pawl.pendingCategories.endsAt"

    private func writeOldCategoryKeys(_ defaults: UserDefaults, gambling: Bool, adult: Bool, end: Double) {
        defaults.set(gambling, forKey: oldCatGambling)
        defaults.set(adult, forKey: oldCatAdult)
        defaults.set(end, forKey: oldCatEnd)
    }

    // 16
    func test_categoryMigration_oldKeys_loadWithExactSameEndTime() {
        let defaults = makeDefaults()
        writeOldCategoryKeys(defaults, gambling: true, adult: false, end: 1_800_000_000)

        let loaded = WebCategories.makeStore(defaults: defaults).load()

        XCTAssertEqual(loaded?.payload, WebCategories(gambling: true, adult: false))
        XCTAssertEqual(loaded?.endsAt.timeIntervalSince1970, 1_800_000_000)   // exact, no drift
    }

    // 17
    func test_categoryMigration_movesToNewKeys_andDeletesOldOnes() {
        let defaults = makeDefaults()
        writeOldCategoryKeys(defaults, gambling: true, adult: false, end: 1_800_000_000)
        let store = WebCategories.makeStore(defaults: defaults)

        _ = store.load()

        XCTAssertNil(defaults.object(forKey: oldCatGambling))
        XCTAssertNil(defaults.object(forKey: oldCatAdult))
        XCTAssertNil(defaults.object(forKey: oldCatEnd))
        XCTAssertEqual(defaults.double(forKey: newCatEnd), 1_800_000_000)
        let data = try! XCTUnwrap(defaults.data(forKey: newCatData))
        XCTAssertEqual(try? JSONDecoder().decode(WebCategories.self, from: data),
                       WebCategories(gambling: true, adult: false))

        let second = store.load()
        XCTAssertEqual(second?.payload, WebCategories(gambling: true, adult: false))
        XCTAssertEqual(second?.endsAt.timeIntervalSince1970, 1_800_000_000)
    }

    // 18
    func test_categoryMigration_oldKeysPastEndTime_restoreCommitsOnce() async {
        let defaults = makeDefaults()
        writeOldCategoryKeys(defaults, gambling: false, adult: true, end: 1_800_000_000)
        let clock = Clock(Date(timeIntervalSince1970: 1_800_000_060))   // a minute after the end
        let ctl = PendingChangeController<WebCategories>(store: WebCategories.makeStore(defaults: defaults),
                                                         now: { clock.now })
        var applied: [WebCategories] = []
        ctl.apply = { applied.append($0) }

        await ctl.restore()

        XCTAssertEqual(applied, [WebCategories(gambling: false, adult: true)])
        XCTAssertNil(ctl.pending)
        XCTAssertNil(ctl.store.load())
        XCTAssertNil(defaults.object(forKey: oldCatEnd))
    }

    // 19
    func test_categoryMigration_nothingOldOrNew_returnsNilAndWritesNothing() {
        let defaults = makeDefaults()
        let store = WebCategories.makeStore(defaults: defaults)

        XCTAssertNil(store.load())

        for key in [oldCatGambling, oldCatAdult, oldCatEnd, newCatData, newCatEnd] {
            XCTAssertNil(defaults.object(forKey: key), key)
        }
    }

    // 20 (cannot happen in practice; pins the rule)
    func test_categoryMigration_oldAndNewBothPresent_newWinsAndOldIsDeleted() {
        let defaults = makeDefaults()
        let store = WebCategories.makeStore(defaults: defaults)
        store.save(PendingChange(payload: WebCategories(gambling: false, adult: false), endsAt: t0))
        writeOldCategoryKeys(defaults, gambling: true, adult: true, end: 1_700_000_000)

        let loaded = store.load()

        XCTAssertEqual(loaded?.payload, WebCategories(gambling: false, adult: false))
        XCTAssertEqual(loaded?.endsAt, t0)
        XCTAssertNil(defaults.object(forKey: oldCatGambling))
        XCTAssertNil(defaults.object(forKey: oldCatAdult))
        XCTAssertNil(defaults.object(forKey: oldCatEnd))
    }

    // MARK: Duration migration (old pawl.pendingDur.* keys)

    // 21
    func test_durationMigration_oldKeys_loadIntoDurationPair_andOldKeysGo() {
        // The 2.2 key names, copied here as constants so this test keeps pinning them.
        let oldCooldown = "pawl.pendingDur.cooldown"
        let oldGrace = "pawl.pendingDur.grace"
        let oldEnd = "pawl.pendingDur.endsAt"
        let defaults = makeDefaults()
        defaults.set(1800.0, forKey: oldCooldown)
        defaults.set(300.0, forKey: oldGrace)
        defaults.set(1_800_000_000.0, forKey: oldEnd)
        let store = DurationPair.makeStore(defaults: defaults)

        let loaded = store.load()

        XCTAssertEqual(loaded?.payload, DurationPair(cooldown: 1800, grace: 300))
        XCTAssertEqual(loaded?.endsAt.timeIntervalSince1970, 1_800_000_000)   // exact, no drift
        XCTAssertNil(defaults.object(forKey: oldCooldown))
        XCTAssertNil(defaults.object(forKey: oldGrace))
        XCTAssertNil(defaults.object(forKey: oldEnd))
        // Deleting the old keys must not take the moved change with it.
        let second = store.load()
        XCTAssertEqual(second?.payload, DurationPair(cooldown: 1800, grace: 300))
        XCTAssertEqual(second?.endsAt.timeIntervalSince1970, 1_800_000_000)
    }

    // 22
    func test_durationFacade_matchesWhatTheControllerHolds() {
        let clock = Clock(t0)
        let ctl = PendingChangeController<DurationPair>(store: DurationPair.makeStore(defaults: makeDefaults()),
                                                       now: { clock.now })
        let endsAt = t0.addingTimeInterval(900)
        ctl.begin(DurationPair(cooldown: 1800, grace: 300), endsAt: endsAt)

        let facade = ctl.pending.map { PendingDurations($0) }

        XCTAssertEqual(facade, PendingDurations(cooldown: 1800, grace: 300, endsAt: endsAt))
        ctl.clear()
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
