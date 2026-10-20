// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  Suggestions.swift
//  Pawl, Domain core (2.3)
//
//  Popular things to block, by focus. Websites are one-tap chips (plain addresses, so Pawl can
//  add them). Apps are names only: Screen Time never tells Pawl which apps are installed and
//  can't pre-select them, so the person searches for them in Apple's picker. Nothing here is
//  ever added on its own; every pick is a tap.
//

import Foundation

public extension Vertical {
    /// Bare hostnames, shown as "tap to block" chips. Empty where a category already covers it
    /// (adult content uses Apple's filter).
    var suggestedSites: [String] {
        switch self {
        case .social:       return ["instagram.com", "tiktok.com", "x.com", "facebook.com", "reddit.com", "snapchat.com", "threads.net"]
        case .games:        return ["roblox.com", "twitch.tv", "store.steampowered.com", "epicgames.com", "chess.com", "poki.com"]
        case .shopping:     return ["amazon.com", "temu.com", "shein.com", "ebay.com", "etsy.com", "walmart.com"]
        case .news:         return ["news.google.com", "cnn.com", "foxnews.com", "nytimes.com", "yahoo.com", "x.com"]
        case .adultContent: return []
        case .gambling:     return ["kalshi.com", "polymarket.com"]
        case .custom:       return ["youtube.com", "instagram.com", "tiktok.com", "reddit.com", "x.com", "netflix.com"]
        }
    }

    /// App names people with this focus commonly block, to search for in Apple's picker.
    var suggestedApps: [String] {
        switch self {
        case .social:       return ["Instagram", "TikTok", "X", "Snapchat", "Facebook", "Reddit"]
        case .games:        return ["Roblox", "Fortnite", "Clash Royale", "Candy Crush", "Twitch"]
        case .shopping:     return ["Amazon", "Temu", "Shein", "eBay"]
        case .news:         return ["News", "X", "Reddit", "Threads"]
        case .adultContent: return []
        case .gambling:     return ["DraftKings", "FanDuel", "PrizePicks", "Stake"]
        case .custom:       return ["YouTube", "Instagram", "TikTok", "Netflix"]
        }
    }

    /// "Popular picks: Instagram, TikTok, X. Search for them in Apple's list." nil when none.
    var suggestedAppsLine: String? {
        let names = suggestedApps
        guard !names.isEmpty else { return nil }
        return "Popular picks: \(names.joined(separator: ", ")). Search for them in Apple's list."
    }
}
