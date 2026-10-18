// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  PendingChange.swift
//  Pawl, one shared mechanism for changes that wait out the cooling-off (2.3)
//
//  Five places in AppModel save a change, wait, then apply it: the app selection, the website
//  categories, the cooldown and grace durations, typed sites, and scheduled sets. Each had its
//  own copy of the timer, restore, commit and clear code. This file holds that code once.
//
//  What this file does NOT do, on purpose: decide whether a change blocks less, call the key
//  gate (approveLoosening), touch the shield, or set any message a person reads. Every caller
//  passes the gate before it calls begin(_:endsAt:). Keeping the gate out of here keeps the
//  product promise out of the refactor.
//

import Foundation
import Observation

/// One pending change and the moment it applies. This is the only thing that gets saved.
public struct PendingChange<Payload: Codable & Equatable>: Codable, Equatable {
    public var payload: Payload
    public var endsAt: Date

    public init(payload: Payload, endsAt: Date) {
        self.payload = payload
        self.endsAt = endsAt
    }
}

/// Saves one pending change in UserDefaults under two keys:
/// `<name>.data` holds the payload as JSON, and `<name>.endsAt` holds the end time as a Double
/// of seconds since 1970. That is the same layout SelectionChangeStore used, so a store with
/// the same name reads what the old store wrote.
@MainActor
public final class PendingChangeStore<Payload: Codable & Equatable> {

    /// How to read and delete a pending change saved in an older layout. Only paths that moved
    /// keys use this (web categories, durations). `load` returns nil when nothing old is there.
    public struct Legacy {
        public var load: () -> PendingChange<Payload>?
        public var delete: () -> Void

        public init(load: @escaping () -> PendingChange<Payload>?, delete: @escaping () -> Void) {
            self.load = load
            self.delete = delete
        }
    }

    public let name: String
    private let defaults: UserDefaults
    private let legacy: Legacy?

    private var dataKey: String { name + ".data" }
    private var endKey: String { name + ".endsAt" }

    public init(name: String, defaults: UserDefaults = .standard, legacy: Legacy? = nil) {
        self.name = name
        self.defaults = defaults
        self.legacy = legacy
    }

    public func save(_ change: PendingChange<Payload>) {
        guard let data = try? JSONEncoder().encode(change.payload) else { return }
        defaults.set(data, forKey: dataKey)
        defaults.set(change.endsAt.timeIntervalSince1970, forKey: endKey)
    }

    /// The saved change, or nil. New keys first. If they are empty and an old layout has a
    /// change, it is copied to the new keys with the exact same end time, the old keys are
    /// deleted, and it is returned. If both exist, the new keys win and the old ones go.
    public func load() -> PendingChange<Payload>? {
        if let current = loadCurrent() {
            if let legacy, legacy.load() != nil { legacy.delete() }
            return current
        }
        guard let legacy, let old = legacy.load() else { return nil }
        save(old)
        // Delete the old keys only once the copy reads back, so a failed write loses nothing.
        if loadCurrent() == old { legacy.delete() }
        return old
    }

    /// Removes both keys, and any old-layout keys too, so a cancelled change can never come back.
    public func clear() {
        defaults.removeObject(forKey: dataKey)
        defaults.removeObject(forKey: endKey)
        legacy?.delete()
    }

    private func loadCurrent() -> PendingChange<Payload>? {
        let end = defaults.double(forKey: endKey)
        guard end > 0,
              let data = defaults.data(forKey: dataKey),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return nil }
        return PendingChange(payload: payload, endsAt: Date(timeIntervalSince1970: end))
    }
}

/// Owns one store and one timer: save, wait, apply, clear. AppModel keeps one per path.
@MainActor
@Observable
public final class PendingChangeController<Payload: Codable & Equatable> {

    /// The single source of truth for views. Nil when nothing is waiting.
    public private(set) var pending: PendingChange<Payload>?

    /// When the waiting change applies, or nil.
    public var endsAt: Date? { pending?.endsAt }

    /// The only path-specific behavior. AppModel sets it once. It never includes the key gate.
    @ObservationIgnored public var apply: @MainActor (Payload) async -> Void = { _ in }

    public let store: PendingChangeStore<Payload>
    private let now: () -> Date
    @ObservationIgnored private var timer: Task<Void, Never>?
    /// Stops two callers (a launch restore and the timer, say) from applying the same change twice.
    @ObservationIgnored private var committing = false

    public init(store: PendingChangeStore<Payload>, now: @escaping () -> Date = { Date() }) {
        self.store = store
        self.now = now
    }

    /// Save a change and start waiting. The caller has already passed the gate.
    public func begin(_ payload: Payload, endsAt: Date) {
        let change = PendingChange(payload: payload, endsAt: endsAt)
        store.save(change)
        pending = change
        schedule(at: endsAt)
    }

    /// On launch: apply a change whose wait already ended, or resume waiting for one that hasn't.
    public func restore() async {
        guard let change = store.load() else { return }
        if now() >= change.endsAt {
            await commit()
        } else {
            pending = change
            schedule(at: change.endsAt)
        }
    }

    /// Apply the saved change, then clear it. Same order as before: apply first, then clear.
    public func commit() async {
        guard !committing, let change = store.load() else { return }
        committing = true
        defer { committing = false }
        await apply(change.payload)
        clear()
    }

    /// Stop the timer and forget the change.
    public func clear() {
        timer?.cancel()
        timer = nil
        store.clear()
        pending = nil
    }

    /// The same Task.sleep timer each path had before, now in one place.
    private func schedule(at endsAt: Date) {
        timer?.cancel()
        timer = Task { [weak self] in
            let delay = endsAt.timeIntervalSince(self?.now() ?? Date())
            if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            if Task.isCancelled { return }
            await self?.commit()
        }
    }
}

// MARK: - Payload types for the paths that had no typed store

/// Which website categories should be on once a pending turn-off applies (step 2). Before 2.3
/// this lived in three raw UserDefaults keys; `makeStore` reads that old layout once and moves it.
public struct WebCategories: Codable, Equatable {
    public var gambling: Bool
    public var adult: Bool

    public init(gambling: Bool, adult: Bool) {
        self.gambling = gambling
        self.adult = adult
    }

    /// The 2.2 keys. Kept only so a turn-off saved by 2.2 is picked up after the update.
    static let oldGamblingKey = "pawl.pendingCat.gambling"
    static let oldAdultKey    = "pawl.pendingCat.adult"
    static let oldEndKey      = "pawl.pendingCat.endsAt"

    /// The store AppModel uses. A brand-new name on purpose, so no old key can be mistaken for
    /// a new one. The end time moves over as the exact same Double, so a person mid-wait keeps
    /// exactly the time they had.
    @MainActor
    public static func makeStore(defaults: UserDefaults = .standard) -> PendingChangeStore<WebCategories> {
        PendingChangeStore(
            name: "pawl.pendingCategories",
            defaults: defaults,
            legacy: PendingChangeStore<WebCategories>.Legacy(
                load: {
                    let end = defaults.double(forKey: oldEndKey)
                    guard end > 0 else { return nil }
                    return PendingChange(
                        payload: WebCategories(gambling: defaults.bool(forKey: oldGamblingKey),
                                               adult: defaults.bool(forKey: oldAdultKey)),
                        endsAt: Date(timeIntervalSince1970: end))
                },
                delete: {
                    defaults.removeObject(forKey: oldGamblingKey)
                    defaults.removeObject(forKey: oldAdultKey)
                    defaults.removeObject(forKey: oldEndKey)
                }))
    }
}
