// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  CloudStore.swift
//  Pawl — persistence
//
//  Thin wrapper over iCloud Key-Value storage (NSUbiquitousKeyValueStore). Data here
//  lives in the user's iCloud, so it SURVIVES deleting + reinstalling the app — the
//  basis for reinstall-proofing (SRS FR-PERSIST). KVS keeps a local cache, so reads
//  work offline and sync up when online.
//
//  Requires the iCloud "Key-value storage" capability in Xcode (one checkbox) and the
//  user to be signed into iCloud. See docs/07_iCloud_Reinstall_Proofing.md.
//

import Foundation

@MainActor
public final class CloudStore {
    public static let shared = CloudStore()

    private let kv = NSUbiquitousKeyValueStore.default

    private init() {
        kv.synchronize()
    }

    public func data(forKey key: String) -> Data? {
        kv.data(forKey: key)
    }

    public func set(_ data: Data?, forKey key: String) {
        if let data {
            kv.set(data, forKey: key)
        } else {
            kv.removeObject(forKey: key)
        }
        kv.synchronize()
    }
}
