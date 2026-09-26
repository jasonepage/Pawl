// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  PawlShared.swift
//  Pawl. Shared between the app and the extensions that actually need it.
//
//  TARGET MEMBERSHIP, corrected 2026-09-03. This file belongs to THREE targets:
//  Pawl, PawlMonitor and PawlShieldAction. It does NOT belong to PawlShield and never
//  did: the shield configuration extension only draws the block screen and touches
//  nothing in here. The old comment said otherwise and was wrong.
//  See docs/06_Extensions_Setup_Checklist.md.
//
//  It defines the App Group container, the shared (named) shield store, the
//  DeviceActivity name, and tiny helpers to share the user's selection + the current
//  unlock phase across processes. Helpers are `nonisolated` so the extensions (which
//  run outside the main actor) can call them safely.
//

import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

public enum AppGroup {
    // Must match the App Group ID added to all three targets in Xcode.
    public nonisolated static let id = "group.io.github.jasonepage.Pawl"

    public nonisolated static var defaults: UserDefaults {
        UserDefaults(suiteName: id) ?? .standard
    }
}

public extension ManagedSettingsStore.Name {
    // A named store is shared between the app and its extensions automatically.
    nonisolated static let pawl = Self("PawlShield")
}

public extension DeviceActivityName {
    nonisolated static let pawlUnlock = Self("pawlUnlock")
}

/// Cross-process shared state (App Group UserDefaults).
public enum SharedState {
    private nonisolated static let selectionKey = "pawl.blockset.selection"
    private nonisolated static let phaseKey = "pawl.unlock.phase"

    public nonisolated static func saveSelection(_ selection: FamilyActivitySelection) {
        if let data = try? JSONEncoder().encode(selection) {
            AppGroup.defaults.set(data, forKey: selectionKey)
        }
    }

    public nonisolated static func loadSelection() -> FamilyActivitySelection {
        guard let data = AppGroup.defaults.data(forKey: selectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return FamilyActivitySelection() }
        return selection
    }

    /// "locked" | "cooling" | "unshielded" — for the app UI to reflect reality.
    public nonisolated static func setPhase(_ phase: String) {
        AppGroup.defaults.set(phase, forKey: phaseKey)
    }
    public nonisolated static func phase() -> String {
        AppGroup.defaults.string(forKey: phaseKey) ?? "locked"
    }

    // The current unlock window, so the app UI can show the right countdown even after
    // being force-quit and reopened.
    private nonisolated static let winStartKey = "pawl.unlock.windowStart"
    private nonisolated static let winEndKey = "pawl.unlock.windowEnd"

    public nonisolated static func setWindow(start: Date, end: Date) {
        AppGroup.defaults.set(start, forKey: winStartKey)
        AppGroup.defaults.set(end, forKey: winEndKey)
    }
    public nonisolated static func windowStart() -> Date? {
        AppGroup.defaults.object(forKey: winStartKey) as? Date
    }
    public nonisolated static func windowEnd() -> Date? {
        AppGroup.defaults.object(forKey: winEndKey) as? Date
    }
    public nonisolated static func clearWindow() {
        AppGroup.defaults.removeObject(forKey: winStartKey)
        AppGroup.defaults.removeObject(forKey: winEndKey)
    }

    // Web blocking config, shared so the extension re-applies it on relock. `enabled` =
    // block the gambling/crypto domain list; `adult` = also turn on Apple's adult filter.
    private nonisolated static let webEnabledKey = "pawl.web.enabled"
    private nonisolated static let webAdultKey = "pawl.web.adult"
    private nonisolated static let webDomainsKey = "pawl.web.domains"

    public nonisolated static func setWebBlock(enabled: Bool, adult: Bool, domains: [String]) {
        AppGroup.defaults.set(enabled, forKey: webEnabledKey)
        AppGroup.defaults.set(adult, forKey: webAdultKey)
        AppGroup.defaults.set(domains, forKey: webDomainsKey)
    }
    /// Set the defaults on first run (block gambling sites, adult filter off); on later runs
    /// keep the user's choices but refresh the domain list in case the seed list changed.
    public nonisolated static func ensureWebDefaults(domains: [String]) {
        if AppGroup.defaults.object(forKey: webEnabledKey) == nil {
            setWebBlock(enabled: true, adult: false, domains: domains)
        } else {
            // Keep the cached (possibly remote-fetched) list, but guarantee the curated seed is
            // always present — so the Tier-1 fetch can grow the list without losing it offline.
            let existing = AppGroup.defaults.stringArray(forKey: webDomainsKey) ?? []
            setWebDomains(Array(Set(existing).union(domains)))
        }
    }

    /// Replace just the blocked-domain list (used by BlocklistService after a remote fetch),
    /// leaving the gambling/adult category flags untouched.
    public nonisolated static func setWebDomains(_ domains: [String]) {
        AppGroup.defaults.set(domains, forKey: webDomainsKey)
    }
    public nonisolated static func webBlockEnabled() -> Bool { AppGroup.defaults.bool(forKey: webEnabledKey) }
    public nonisolated static func webAdultFilter() -> Bool { AppGroup.defaults.bool(forKey: webAdultKey) }
    public nonisolated static func webBlockDomains() -> [String] { AppGroup.defaults.stringArray(forKey: webDomainsKey) ?? [] }
}

/// Apply / lift the shield on the SHARED named store. Used by the app and by the
/// monitor extension so both touch the exact same shield (HC-4, FR-UNLOCK-007/008).
public enum SharedShield {
    public nonisolated static func apply(_ selection: FamilyActivitySelection) {
        let store = ManagedSettingsStore(named: .pawl)
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        applyWebFilter(to: store)
    }

    public nonisolated static func lift() {
        let store = ManagedSettingsStore(named: .pawl)
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.webContent.blockedByFilter = nil        // web unblocks with apps during grace
        // NOTE: deliberately does NOT touch application.denyAppRemoval — Pawl must stay
        // undeletable through the grace window too. That's managed separately by
        // setDeletionBlock(), keyed to the commitment, not the lift/relock cycle.
    }

    /// Block uninstalling Pawl itself while a commitment is active (FR-P3-HARD-002).
    /// Verified on-device (2026-06-23, individual Family Controls auth): `true` removes the
    /// "Delete App" option, leaving only "Remove from Home Screen" — the app stays installed
    /// and the shield keeps running. NOT absolute: revoking Screen Time in Settings still wipes
    /// it (no passcode until the Phase-3 sponsor-set passcode), and that revoke trips the
    /// heartbeat tamper alert. Lives on the same named store and is intentionally left untouched
    /// by apply()/lift() so it persists across grace cycles.
    public nonisolated static func setDeletionBlock(_ on: Bool) {
        ManagedSettingsStore(named: .pawl).application.denyAppRemoval = on ? true : nil
    }

    /// Block the curated gambling/crypto domains by string (the only way iOS shields
    /// arbitrary domains). `.specific` blocks ONLY those domains; `.auto` additionally turns
    /// on Apple's adult-content filter. Any filter other than `.none` also disables Safari
    /// private browsing — a feature here, since that was a loophole.
    private nonisolated static func applyWebFilter(to store: ManagedSettingsStore) {
        // Two independent categories chosen at onboarding (multi-select):
        //   gambling = block our curated gambling/crypto domain list
        //   adult    = turn on Apple's built-in "Limit Adult Websites" filter (.auto)
        let gambling = SharedState.webBlockEnabled()
        let adult = SharedState.webAdultFilter()
        let webDomains = gambling
            ? Set(SharedState.webBlockDomains().map { WebDomain(domain: $0) })
            : Set<WebDomain>()

        switch (adult, gambling) {
        case (false, false):
            store.webContent.blockedByFilter = nil
        case (true, _):
            // Apple's adult filter, plus any gambling domains we also block.
            store.webContent.blockedByFilter = .auto(webDomains, except: [])
        case (false, true):
            store.webContent.blockedByFilter = webDomains.isEmpty ? nil : .specific(webDomains)
        }
    }
}

// MARK: - Caught attempts + urge handoff (FR-SHACT-002/004/005, spec docs/16)
//
// Written by the PawlShieldAction extension at the exact moment someone opens a blocked
// app, and read by the app. App Group UserDefaults on purpose: synchronous, local, and
// impossible to fail at the one moment that matters. Nothing here touches the network.
//
// Privacy: a timestamp and nothing else. iOS never tells the extension which app was
// blocked, and Pawl does not need to know.

public extension SharedState {
    private nonisolated static var attemptsKey: String { "pawl.shield.attempts" }
    private nonisolated static var pendingUrgeKey: String { "pawl.shield.pendingUrge" }

    /// Retention for the raw timestamps. Thirty days is enough for every window the UI shows.
    private nonisolated static var attemptRetention: TimeInterval { 30 * 24 * 60 * 60 }
    /// Hard cap so a bad day cannot grow the defaults file without limit.
    private nonisolated static var attemptCap: Int { 200 }

    /// Record one caught attempt. Called from the shield action extension only.
    nonisolated static func recordBlockAttempt(now: Date = Date()) {
        var stamps = (AppGroup.defaults.array(forKey: attemptsKey) as? [Double]) ?? []
        stamps.append(now.timeIntervalSince1970)
        let cutoff = now.timeIntervalSince1970 - attemptRetention
        stamps = stamps.filter { $0 >= cutoff }
        if stamps.count > attemptCap { stamps = Array(stamps.suffix(attemptCap)) }
        AppGroup.defaults.set(stamps, forKey: attemptsKey)
    }

    /// How many attempts Pawl caught in the last `days` days.
    nonisolated static func blockAttempts(inLastDays days: Int, now: Date = Date()) -> Int {
        let stamps = (AppGroup.defaults.array(forKey: attemptsKey) as? [Double]) ?? []
        let cutoff = now.timeIntervalSince1970 - (Double(days) * 24 * 60 * 60)
        return stamps.filter { $0 >= cutoff }.count
    }

    /// Every retained timestamp, oldest first. For the app when it syncs counts upstream.
    nonisolated static func blockAttemptStamps() -> [Date] {
        ((AppGroup.defaults.array(forKey: attemptsKey) as? [Double]) ?? [])
            .sorted()
            .map { Date(timeIntervalSince1970: $0) }
    }

    /// Someone pressed "I need a minute" on the block screen. A shield action extension
    /// cannot open its containing app, so this is a deferred handoff: the app picks it up
    /// the next time it becomes active.
    nonisolated static func setPendingUrge(now: Date = Date()) {
        AppGroup.defaults.set(now.timeIntervalSince1970, forKey: pendingUrgeKey)
    }

    /// Returns true at most once per press, and only while the press is still fresh.
    /// A prompt about an urge from yesterday is worse than no prompt (FR-SHACT-005).
    nonisolated static func consumePendingUrge(now: Date = Date(),
                                              within seconds: TimeInterval = 30 * 60) -> Bool {
        let stamp = AppGroup.defaults.double(forKey: pendingUrgeKey)
        guard stamp > 0 else { return false }
        AppGroup.defaults.removeObject(forKey: pendingUrgeKey)
        return (now.timeIntervalSince1970 - stamp) <= seconds
    }
}

// MARK: - Clock lock (FR-CLOCK-001)

public extension SharedShield {
    /// Require automatic date and time while a commitment is active, so the device clock
    /// cannot be moved forward to skip the cooling off window.
    ///
    /// UNVERIFIED ON DEVICE under individual Family Controls authorization. The call is
    /// harmless if iOS ignores it, but do not ship Settings copy that promises it until
    /// step six of the test plan in docs/16 has actually been run.
    nonisolated static func setClockLock(_ on: Bool) {
        ManagedSettingsStore(named: .pawl).dateAndTime.requireAutomaticDateAndTime = on ? true : nil
    }
}
