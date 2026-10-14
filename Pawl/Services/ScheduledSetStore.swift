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
//

import Foundation
import DeviceActivity

@MainActor
public final class ScheduledSetStore {
    private let cloudKey = "pawl.sets.scheduled"
    private let pendingSetsKey = "pawl.pendingSets.target"
    private let pendingEndKey = "pawl.pendingSets.endsAt"
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

    public struct PendingSets: Equatable {
        public let target: [ScheduledSet]
        public let endsAt: Date
    }

    public func savePending(_ p: PendingSets) {
        let d = UserDefaults.standard
        d.set(try? JSONEncoder().encode(p.target), forKey: pendingSetsKey)
        d.set(p.endsAt.timeIntervalSince1970, forKey: pendingEndKey)
    }

    public func loadPending() -> PendingSets? {
        let d = UserDefaults.standard
        let end = d.double(forKey: pendingEndKey)
        guard end > 0, let data = d.data(forKey: pendingSetsKey),
              let target = try? JSONDecoder().decode([ScheduledSet].self, from: data) else { return nil }
        return PendingSets(target: target, endsAt: Date(timeIntervalSince1970: end))
    }

    public func clearPending() {
        let d = UserDefaults.standard
        d.removeObject(forKey: pendingSetsKey)
        d.removeObject(forKey: pendingEndKey)
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
