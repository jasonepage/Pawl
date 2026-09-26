// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  SelectionChangeStore.swift
//  Pawl — key-gated blocklist editing (FR-SHIELD-010)
//
//  A pending *removal* of targets from an active shield: the new (reduced) selection plus when
//  it may take effect. Adding targets never goes through here (tightening is free, FR-SHIELD-009).
//  Persisted so force-quitting can't skip the cooling-off that gates a removal (same idea as the
//  gated re-pair and gated duration loosening).
//

import Foundation
import FamilyControls

public struct PendingSelectionChange {
    public var selection: FamilyActivitySelection
    public var endsAt: Date
}

@MainActor
public final class SelectionChangeStore {
    private let defaults = UserDefaults.standard
    private let selKey = "pawl.pendingSel.data"
    private let endKey = "pawl.pendingSel.endsAt"

    public init() {}

    public func save(_ p: PendingSelectionChange) {
        guard let data = try? JSONEncoder().encode(p.selection) else { return }
        defaults.set(data, forKey: selKey)
        defaults.set(p.endsAt.timeIntervalSince1970, forKey: endKey)
    }

    public func load() -> PendingSelectionChange? {
        let end = defaults.double(forKey: endKey)
        guard end > 0,
              let data = defaults.data(forKey: selKey),
              let sel = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return nil }
        return PendingSelectionChange(selection: sel, endsAt: Date(timeIntervalSince1970: end))
    }

    public func clear() {
        defaults.removeObject(forKey: selKey)
        defaults.removeObject(forKey: endKey)
    }
}
