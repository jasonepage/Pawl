// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  TrustedContact.swift
//  Pawl — urge support
//
//  A trusted person the user can one-tap call from the urge screen (FR-URGE-005). Stored in
//  iCloud KVS so it survives reinstall, like the rest of the commitment state. Optional —
//  the urge flow works without it.
//

import Foundation

enum TrustedContact {
    private static let nameKey = "pawl.trusted.name"
    private static let phoneKey = "pawl.trusted.phone"

    @MainActor static func name() -> String? { read(nameKey) }
    @MainActor static func phone() -> String? { read(phoneKey) }

    @MainActor static func save(name: String?, phone: String?) {
        write(name, key: nameKey)
        write(phone, key: phoneKey)
    }

    @MainActor private static func read(_ key: String) -> String? {
        guard let data = CloudStore.shared.data(forKey: key),
              let s = String(data: data, encoding: .utf8), !s.isEmpty else { return nil }
        return s
    }

    @MainActor private static func write(_ value: String?, key: String) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        CloudStore.shared.set(trimmed.isEmpty ? nil : Data(trimmed.utf8), forKey: key)
    }
}
