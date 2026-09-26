// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  GamblingBlocklist.swift
//  Pawl — Domain core
//
//  A curated seed list of well-known gambling + crypto-exchange web domains, so a new user
//  doesn't have to hunt for sites to block. A SEED, not exhaustive — users add their own.
//
//  NOTE ON ENFORCEMENT: iOS only shields arbitrary string domains via the ManagedSettings
//  `webContent` filter (`.auto`), which also enables Apple's adult-content filter as a side
//  effect and needs on-device testing. Until that's wired (and that side effect is a product
//  decision), this list is data we can attach to a BlockSet — see HANDOFF "stronger blocking".
//

import Foundation

public enum GamblingBlocklist {
    /// Bare hostnames (no scheme, no "www."). Grouped by category for readability.
    public static let seedDomains: [String] = [
        // Sportsbooks
        "draftkings.com", "fanduel.com", "betmgm.com", "caesars.com",
        "espnbet.com", "betrivers.com", "pointsbet.com", "bet365.com",
        "hardrock.bet", "fanatics.com", "williamhill.com", "wynnbet.com",
        "betway.com", "unibet.com",

        // Daily fantasy / pick'em
        "prizepicks.com", "underdogfantasy.com", "sleeper.com",

        // Casino / poker / slots
        "bovada.lv", "stake.com", "pokerstars.com", "888casino.com",
        "chumbacasino.com", "luckylandslots.com", "borgataonline.com",
        "goldennuggetcasino.com", "draftkingscasino.com",

        // Crypto exchanges (in scope per the project brief)
        "coinbase.com", "binance.com", "binance.us", "kraken.com",
        "crypto.com", "gemini.com", "kucoin.com", "bybit.com",
    ]
}
