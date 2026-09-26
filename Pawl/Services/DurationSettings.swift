// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  DurationSettings.swift
//  Pawl — friction customization (cooldown + grace)
//
//  A pending *loosening* of the cooldown/grace: the new (looser) values plus when they may
//  take effect. Stricter changes apply immediately and never go through here. Persisted so
//  force-quitting can't skip the wait that gates a loosening (same idea as the gated re-pair).
//

import Foundation

public struct PendingDurations: Equatable, Sendable {
    public var cooldown: TimeInterval
    public var grace: TimeInterval
    public var endsAt: Date
}

@MainActor
public final class DurationStore {
    private let defaults: UserDefaults
    private let cdKey = "pawl.pendingDur.cooldown"
    private let grKey = "pawl.pendingDur.grace"
    private let endKey = "pawl.pendingDur.endsAt"

    public init(suiteName: String? = nil) {
        self.defaults = suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    public func save(_ p: PendingDurations) {
        defaults.set(p.cooldown, forKey: cdKey)
        defaults.set(p.grace, forKey: grKey)
        defaults.set(p.endsAt.timeIntervalSince1970, forKey: endKey)
    }

    public func load() -> PendingDurations? {
        let end = defaults.double(forKey: endKey)
        guard end > 0 else { return nil }
        return PendingDurations(
            cooldown: defaults.double(forKey: cdKey),
            grace: defaults.double(forKey: grKey),
            endsAt: Date(timeIntervalSince1970: end)
        )
    }

    public func clear() {
        defaults.removeObject(forKey: cdKey)
        defaults.removeObject(forKey: grKey)
        defaults.removeObject(forKey: endKey)
    }
}
