// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  LegacySponsorCleanup.swift
//  Pawl — 2.3 upgrade
//
//  2.3 removed the ally (sponsor) feature and the Supabase backend behind it. The physical key
//  is the accountability now: whoever holds it decides when Pawl can loosen. Earlier versions
//  left a few things on the phone. This retires them quietly on launch.
//
//  Rules: never throws, never crashes, never touches the shield, the paired key, the streak,
//  the slip and urge logs, or any pending change. Every step is safe to repeat, so it simply
//  runs on every launch (each one is a cheap no-op once the item is gone).
//

import Foundation
import Security

enum LegacySponsorCleanup {
    /// Keychain services earlier versions wrote. Keychain items outlive deleting the app, so
    /// they are cleared even on a fresh install.
    private static let keychainServices = [
        "io.github.jasonepage.Pawl.sponsorLatch",   // 2.1 SponsorLatch: "this phone has an ally"
        "supabase.gotrue.swift",                    // the Supabase package's saved sign-in session
    ]

    @MainActor static func run() {
        for service in keychainServices {
            let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                        kSecAttrService as String: service]
            let status = SecItemDelete(query as CFDictionary)
            #if DEBUG
            if status != errSecSuccess && status != errSecItemNotFound {
                print("[LegacySponsorCleanup] delete \(service) failed: OSStatus \(status)")
            }
            #else
            _ = status
            #endif
        }
        // The 2.0 Pro grandfather flags (ally features free for life) in the App Group.
        ProStore.retireGrandfatherFlags()
        // Someone set up only to approve for others goes through setup as a blocker.
        OnboardingFlag.retireApproverRole()
    }
}
