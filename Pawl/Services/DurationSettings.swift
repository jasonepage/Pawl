// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  DurationSettings.swift
//  Pawl — friction customization (cooldown + grace)
//
//  A pending *loosening* of the cooldown/grace: the new (looser) values plus when they may
//  take effect. Stricter changes apply immediately and never go through here.
//
//  2.3: the saving, waiting and applying moved to PendingChangeController (PendingChange.swift),
//  with DurationPair as its payload. PendingDurations stays as the type views read.
//

import Foundation

public struct PendingDurations: Equatable, Sendable {
    public var cooldown: TimeInterval
    public var grace: TimeInterval
    public var endsAt: Date
}

extension PendingDurations {
    /// The view-facing shape of a pending duration change held by the controller.
    init(_ change: PendingChange<DurationPair>) {
        self.init(cooldown: change.payload.cooldown, grace: change.payload.grace, endsAt: change.endsAt)
    }
}
