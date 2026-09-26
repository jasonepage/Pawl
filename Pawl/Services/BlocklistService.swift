// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  BlocklistService.swift
//  Pawl — Tier-1 blocklist expansion
//
//  Grows the gambling web blocklist past the curated ~35 seed domains WITHOUT shipping a new
//  app release (docs/Blocklist_Expansion_Plan.md). On launch the app fetches a maintained list
//  from a public Supabase table and merges it into the App Group web filter; the existing
//  `SharedShield` web filter then enforces it. `GamblingBlocklist.seedDomains` is the always-
//  present offline fallback.
//
//  The table is public (anon read) — no sign-in needed. Fail-safe: any error leaves the
//  current (seed or last-cached) list active. Screen Time's `webContent` filter isn't built for
//  six-figure counts (that's Tier 2 / NEFilterDataProvider), so we cap defensively.
//

import Foundation
import Supabase

@MainActor
public enum BlocklistService {
    private static let client = Supa.client
    /// Defensive cap so a runaway remote list can't degrade the Screen Time filter. Tune against
    /// the on-device performance test noted in the expansion plan.
    static let maxDomains = 4000

    private struct Row: Decodable { let domain: String }

    /// Fetch the maintained gambling list and merge it into the App Group filter.
    /// Returns true if the stored list actually changed (so the caller can re-apply the shield).
    @discardableResult
    public static func fetchAndStore() async -> Bool {
        do {
            // Page through results. PostgREST caps a single response (commonly 1000 rows) — even
            // an explicit .limit() can't exceed the server's max-rows — so loop with explicit
            // ranges until a short page (the end) or our own defensive cap.
            var fetched: [String] = []
            let pageSize = 1000
            var offset = 0
            while fetched.count < maxDomains {
                let page: [Row] = try await client
                    .from("blocklist_domains")
                    .select("domain")
                    .eq("category", value: "gambling")
                    .range(from: offset, to: offset + pageSize - 1)
                    .execute()
                    .value
                fetched.append(contentsOf: page.map(\.domain))
                if page.count < pageSize { break }   // reached the end
                offset += pageSize
            }
            guard !fetched.isEmpty else { return false }   // empty table → keep seed/cache
            let merged = normalizedMerge(fetched, seed: GamblingBlocklist.seedDomains)
            guard Set(merged) != Set(SharedState.webBlockDomains()) else { return false }
            SharedState.setWebDomains(merged)
            return true
        } catch {
            return false   // offline / transient — seed or last-cached list stays active
        }
    }

    /// Normalize to bare lowercase hostnames, union with the seed, dedupe, and cap.
    static func normalizedMerge(_ fetched: [String], seed: [String]) -> [String] {
        func clean(_ raw: String) -> String? {
            var h = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !h.isEmpty, !h.hasPrefix("#") else { return nil }       // skip comments
            if let r = h.range(of: "://") { h = String(h[r.upperBound...]) }  // strip scheme
            if h.hasPrefix("www.") { h.removeFirst(4) }
            h = h.split(separator: "/").first.map(String.init) ?? h        // strip path
            return h.contains(".") ? h : nil                              // must be a hostname
        }
        var set = Set(seed.compactMap(clean))                            // seed always present
        for d in fetched.compactMap(clean) {
            if set.count >= maxDomains { break }
            set.insert(d)
        }
        return Array(set)
    }
}
