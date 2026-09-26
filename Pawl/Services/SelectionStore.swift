// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  SelectionStore.swift
//  Pawl — iOS integration layer
//
//  Persists the user's FamilyActivitySelection (opaque tokens; HC-1, FR-SHIELD-002).
//  Writes to BOTH:
//   • the App Group (so the extensions can read it at runtime), and
//   • iCloud Key-Value storage (so it survives delete + reinstall — FR-PERSIST).
//  On reinstall the App Group is wiped; `restoreFromCloudIfNeeded()` pulls it back.
//

import Foundation
import FamilyControls

@MainActor
public final class SelectionStore {
    private let cloudKey = "pawl.cloud.selection"

    public init() {}

    public func save(_ selection: FamilyActivitySelection) {
        SharedState.saveSelection(selection)                       // App Group (extensions)
        if let data = try? JSONEncoder().encode(selection) {
            CloudStore.shared.set(data, forKey: cloudKey)          // iCloud (reinstall-proof)
        }
    }

    public func load() -> FamilyActivitySelection {
        SharedState.loadSelection()
    }

    public func clear() {
        SharedState.saveSelection(FamilyActivitySelection())
        CloudStore.shared.set(nil, forKey: cloudKey)
    }

    /// After a reinstall the App Group is empty but iCloud still has the selection.
    /// Copy it back so the shield can be re-applied (FR-PERSIST-002).
    public func restoreFromCloudIfNeeded() {
        let current = SharedState.loadSelection()
        let isEmpty = current.applicationTokens.isEmpty
            && current.categoryTokens.isEmpty
            && current.webDomainTokens.isEmpty
        guard isEmpty,
              let data = CloudStore.shared.data(forKey: cloudKey),
              let restored = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }
        SharedState.saveSelection(restored)
    }
}
