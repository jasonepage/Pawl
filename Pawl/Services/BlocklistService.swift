// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  BlocklistService.swift
//  Pawl — website list helpers
//
//  2.3: this used to download a maintained gambling list from a public Supabase table on
//  launch. The download went away with the backend. The gambling list is now bundled
//  (GamblingBlocklist.seedDomains), and a domain list a pre-2.3 version downloaded stays in the
//  App Group cache untouched (SharedState.ensureWebDefaults only ever adds to it).
//
//  What is left is the one shared hostname cleaner, used for the user's typed list (2.2).
//

import Foundation

@MainActor
public enum BlocklistService {
    /// Bare lowercase hostname from whatever someone typed or a list shipped: strips scheme,
    /// "www.", path, query and port. nil for blanks, comments and anything without a dot.
    /// Used for the user's typed list (2.2).
    public static func cleanHostname(_ raw: String) -> String? {
        var h = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !h.isEmpty, !h.hasPrefix("#") else { return nil }       // skip comments
        if let r = h.range(of: "://") { h = String(h[r.upperBound...]) }  // strip scheme
        if h.hasPrefix("www.") { h.removeFirst(4) }
        h = h.split(separator: "/").first.map(String.init) ?? h        // strip path
        h = h.split(separator: "?").first.map(String.init) ?? h        // strip query
        h = h.split(separator: ":").first.map(String.init) ?? h        // strip port
        guard h.contains("."), !h.hasPrefix("."), !h.hasSuffix("."),
              h.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" })
        else { return nil }
        return h
    }
}
