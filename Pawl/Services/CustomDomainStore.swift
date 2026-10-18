// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  CustomDomainStore.swift
//  Pawl, iOS integration layer (2.2)
//
//  The user's own typed website list (FR-SHIELD-003/004). Two homes, on purpose:
//    • App Group UserDefaults is where the shield reads it (SharedState.customWebDomains),
//      so the monitor extension re-applies the same list on every relock.
//    • iCloud key-value storage is a mirror so the list survives deleting the app, like the
//      streak does (docs/07_iCloud_Reinstall_Proofing.md).
//  Nothing here goes to Supabase. A typed site is the user's business, not the sponsor's.
//
//  Removal is an unlock action (key, sponsor if linked, then cooldown), the same rule as
//  removing an app or switching off a website category (FR-SHIELD-010). 2.3: the pending
//  removal is saved and timed by PendingChangeController; `makePendingStore` below names its
//  store and moves a removal saved by 2.2 over to it.
//

import Foundation

@MainActor
public final class CustomDomainStore {
    private let cloudKey = "pawl.web.customDomains"

    /// Hard cap so a pasted list cannot grow the shield filter without limit.
    public static let maxDomains = 500

    public init() {}

    // MARK: - The list

    public func load() -> [String] { SharedState.customWebDomains() }

    public func save(_ domains: [String]) {
        let clean = Array(Set(domains.compactMap(BlocklistService.cleanHostname))).sorted()
        let capped = Array(clean.prefix(Self.maxDomains))
        SharedState.setCustomWebDomains(capped)
        CloudStore.shared.set(try? JSONEncoder().encode(capped), forKey: cloudKey)
    }

    /// After a reinstall the App Group is empty but iCloud still has the list. Union, never
    /// replace: whichever side has more protection wins.
    public func restoreFromCloudIfNeeded() {
        guard let data = CloudStore.shared.data(forKey: cloudKey),
              let cloud = try? JSONDecoder().decode([String].self, from: data),
              !cloud.isEmpty else { return }
        let local = load()
        let merged = Set(local).union(cloud)
        if merged.count != local.count { save(Array(merged)) }
    }

    // MARK: - Pending removal (gated)

    /// What views read while a removal waits. AppModel builds it from the controller.
    public struct PendingRemoval: Equatable {
        public let domains: [String]
        public let endsAt: Date
    }

    /// The 2.2 keys: a plain string list and the end time. Kept only so a removal saved by 2.2
    /// is picked up after the update.
    static let oldPendingRemoveKey = "pawl.pendingDomains.remove"
    static let oldPendingEndKey    = "pawl.pendingDomains.endsAt"

    /// The pending-removal store AppModel uses. A new name, so no old key is shared with a new
    /// one; a 2.2 removal moves over once with the exact same end time.
    public static func makePendingStore(defaults: UserDefaults = .standard) -> PendingChangeStore<[String]> {
        let listKey = oldPendingRemoveKey, endKey = oldPendingEndKey   // plain locals for the closures below
        return PendingChangeStore(
            name: "pawl.pendingDomainRemoval",
            defaults: defaults,
            legacy: PendingChangeStore<[String]>.Legacy(
                load: {
                    let end = defaults.double(forKey: endKey)
                    guard end > 0, let domains = defaults.stringArray(forKey: listKey),
                          !domains.isEmpty else { return nil }
                    return PendingChange(payload: domains, endsAt: Date(timeIntervalSince1970: end))
                },
                delete: {
                    defaults.removeObject(forKey: listKey)
                    defaults.removeObject(forKey: endKey)
                }))
    }
}
