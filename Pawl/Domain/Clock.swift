// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  Clock.swift
//  Pawl — Domain core
//
//  A time abstraction so cooling-off / grace logic is testable without real waits.
//  (SDS §7.1 "Time abstraction"; supports FR-UNLOCK-003/006/008.)
//

import Foundation

/// Provides the current time. Inject this everywhere time is read so tests can
/// drive the clock deterministically instead of sleeping.
public protocol Clock: Sendable {
    var now: Date { get }
}

/// Production clock — reads the system wall clock.
public struct SystemClock: Clock {
    public init() {}
    public var now: Date { Date() }
}

/// Test clock — advance time manually. Reference type so callers share one instance.
public final class MutableClock: Clock, @unchecked Sendable {
    private let lock = NSLock()
    private var _now: Date
    public init(_ start: Date = Date(timeIntervalSince1970: 0)) { _now = start }

    public var now: Date {
        lock.lock(); defer { lock.unlock() }
        return _now
    }

    /// Move the clock forward by `interval` seconds.
    public func advance(by interval: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        _now = _now.addingTimeInterval(interval)
    }

    /// Jump the clock to an absolute instant.
    public func set(_ date: Date) {
        lock.lock(); defer { lock.unlock() }
        _now = date
    }
}
