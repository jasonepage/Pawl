// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  GamblingBlocklist.swift
//  Pawl — Domain core
//
//  A curated list of well-known gambling + crypto-exchange web domains, so a new user doesn't
//  have to hunt for sites to block. Not exhaustive: users add their own in Settings.
//
//  NOTE ON ENFORCEMENT: iOS only shields arbitrary string domains via the ManagedSettings
//  `webContent` filter (`.auto`), which also enables Apple's adult-content filter as a side
//  effect and needs on-device testing. Until that's wired (and that side effect is a product
//  decision), this list is data we can attach to a BlockSet — see HANDOFF "stronger blocking".
//

import Foundation

public enum GamblingBlocklist {
    /// Bare hostnames (no scheme, no "www."). 2.3: the 167 domains written for Pawl (the
    /// "pawl-curated" rows of the old shared list), bundled in the app now that the Supabase
    /// download is gone. Sportsbooks, daily fantasy, casinos, sweepstakes casinos and crypto
    /// exchanges. All MPL, unlike the HaGeZi rows the server used to add, which stayed GPL.
    public static let seedDomains: [String] = [
        "draftkings.com", "fanduel.com", "betmgm.com", "caesars.com",
        "espnbet.com", "betrivers.com", "pointsbet.com", "bet365.com",
        "hardrock.bet", "fanatics.com", "williamhill.com", "wynnbet.com",
        "betway.com", "unibet.com", "prizepicks.com", "underdogfantasy.com",
        "sleeper.com", "bovada.lv", "stake.com", "stake.us",
        "pokerstars.com", "888casino.com", "chumbacasino.com", "luckylandslots.com",
        "borgataonline.com", "goldennuggetcasino.com", "draftkingscasino.com", "coinbase.com",
        "binance.com", "binance.us", "kraken.com", "crypto.com",
        "gemini.com", "kucoin.com", "bybit.com", "betparx.com",
        "twinspires.com", "superbook.com", "circasports.com", "betus.com",
        "mybookie.ag", "betonline.ag", "sportsbetting.ag", "xbet.ag",
        "betr.app", "dabble.com", "parlayplay.com", "ownersbox.com",
        "betfair.com", "ladbrokes.com", "coral.co.uk", "paddypower.com",
        "skybet.com", "bwin.com", "888sport.com", "betvictor.com",
        "pinnacle.com", "10bet.com", "parimatch.com", "1xbet.com",
        "22bet.com", "melbet.com", "dafabet.com", "sbobet.com",
        "leovegas.com", "casumo.com", "grosvenorcasinos.com", "tipico.com",
        "betsson.com", "comeon.com", "mrgreen.com", "betfred.com",
        "partypoker.com", "ggpoker.com", "wsop.com", "888poker.com",
        "rollbit.com", "roobet.com", "gamdom.com", "duelbits.com",
        "cloudbet.com", "bitcasino.io", "fortunejack.com", "betfury.com",
        "shuffle.com", "bc.game", "jackpocket.com", "thelotter.com",
        "pch.com", "jackpotparty.com", "doubledowncasino.com", "slotomania.com",
        "pulsz.com", "okx.com", "bitfinex.com", "bitstamp.net",
        "gate.io", "mexc.com", "htx.com", "bitget.com",
        "cex.io", "polymarket.com", "kalshi.com", "predictit.org",
        "manifold.markets", "augur.net", "upbit.com", "bithumb.com",
        "poloniex.com", "bitmart.com", "phemex.com", "whitebit.com",
        "coinex.com", "bitflyer.com", "bitmex.com", "deribit.com",
        "bingx.com", "xt.com", "lbank.com", "probit.com",
        "bitrue.com", "coincheck.com", "dydx.exchange", "gmx.io",
        "hyperliquid.xyz", "bitstarz.com", "7bitcasino.com", "mbitcasino.com",
        "sportsbet.io", "1xbit.com", "primedice.com", "trustdice.win",
        "fairspin.io", "wild.io", "metaspins.com", "jackbit.com",
        "chips.gg", "500.casino", "lucky-block.com", "betplay.io",
        "cryptoleo.com", "vave.com", "gamba.com", "wowvegas.com",
        "mcluck.com", "high5casino.com", "fortunecoins.com", "funrize.com",
        "crowncoinscasino.com", "hellomillions.com", "zulacasino.com", "realprize.com",
        "sweeptastic.com", "csgoempire.com", "csgoroll.com", "hellcase.com",
        "key-drop.com", "datdrop.com", "clash.gg", "skinclub.com",
        "thunderpick.io", "rivalry.com", "ggbet.com", "loot.bet",
        "lotto.com", "jackpot.com", "lottoland.com",
    ]
}
