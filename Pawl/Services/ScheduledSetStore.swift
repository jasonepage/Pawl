// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  ScheduledSetStore.swift
//  Pawl, iOS integration layer (2.2)
//
//  Scheduled block sets: iCloud mirror of the App Group copy (so they survive a reinstall),
//  the pending gated replacement, and the DeviceActivity registrations that wake the
//  monitor extension when a window opens or closes. Nothing goes to Supabase.
//  2.3: the pending replacement is saved and timed by PendingChangeController;
//  `makePendingStore` names its store and moves a change saved by 2.2 over to it.
//

import Foundation
import DeviceActivity

@MainActor
public final class ScheduledSetStore {
    private let cloudKey = "pawl.sets.scheduled"
    private static let center = DeviceActivityCenter()

    public init() {}

    // MARK: - The list

    public func load() -> [ScheduledSet] { SharedState.scheduledSets() }

    public func save(_ sets: [ScheduledSet]) {
        let capped = Array(sets.prefix(ScheduledSet.maxSets))
        SharedState.saveScheduledSets(capped)
        CloudStore.shared.set(try? JSONEncoder().encode(capped), forKey: cloudKey)
        Self.registerActivities(for: capped)
    }

    /// After a reinstall the App Group is empty but iCloud still has the sets.
    public func restoreFromCloudIfNeeded() {
        guard load().isEmpty,
              let data = CloudStore.shared.data(forKey: cloudKey),
              let sets = try? JSONDecoder().decode([ScheduledSet].self, from: data),
              !sets.isEmpty else {
            Self.registerActivities(for: load())    // registrations don't survive a reinstall either
            return
        }
        save(sets)
    }

    // MARK: - Pending (gated) replacement of the whole list

    /// What views read while a change waits. AppModel builds it from the controller.
    public struct PendingSets: Equatable {
        public let target: [ScheduledSet]
        public let endsAt: Date
    }

    /// The 2.2 keys: the target list as JSON and the end time. Kept only so a change saved by
    /// 2.2 is picked up after the update.
    static let oldPendingSetsKey = "pawl.pendingSets.target"
    static let oldPendingEndKey  = "pawl.pendingSets.endsAt"

    /// The pending-change store AppModel uses. A new name, so no old key is shared with a new
    /// one; a 2.2 change moves over once with the exact same end time.
    public static func makePendingStore(defaults: UserDefaults = .standard) -> PendingChangeStore<[ScheduledSet]> {
        let listKey = oldPendingSetsKey, endKey = oldPendingEndKey   // plain locals for the closures below
        return PendingChangeStore(
            name: "pawl.pendingSetsChange",
            defaults: defaults,
            legacy: PendingChangeStore<[ScheduledSet]>.Legacy(
                load: {
                    let end = defaults.double(forKey: endKey)
                    guard end > 0, let data = defaults.data(forKey: listKey),
                          let target = try? JSONDecoder().decode([ScheduledSet].self, from: data)
                    else { return nil }
                    return PendingChange(payload: target, endsAt: Date(timeIntervalSince1970: end))
                },
                delete: {
                    defaults.removeObject(forKey: listKey)
                    defaults.removeObject(forKey: endKey)
                }))
    }

    // MARK: - DeviceActivity

    /// One repeating daily activity per enabled set. The weekday filter is applied when the
    /// union is computed (ScheduledSet.isActive), so a boundary firing on an off day is a
    /// harmless reapply of the same shield. iOS needs a window of at least 15 minutes.
    static func registerActivities(for sets: [ScheduledSet]) {
        let stale = center.activities.filter { $0.rawValue.hasPrefix(DeviceActivityName.scheduledSetPrefix) }
        if !stale.isEmpty { center.stopMonitoring(stale) }

        for set in sets where set.isEnabled && !set.weekdays.isEmpty {
            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: set.startMinute / 60, minute: set.startMinute % 60),
                intervalEnd: DateComponents(hour: set.endMinute / 60, minute: set.endMinute % 60),
                repeats: true
            )
            do {
                try center.startMonitoring(.scheduledSet(set.id), during: schedule)
            } catch {
                #if DEBUG
                print("[ScheduledSetStore] could not monitor \(set.name): \(error)")
                #endif
            }
        }
    }
}
