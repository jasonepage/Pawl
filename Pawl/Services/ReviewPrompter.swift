// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  ReviewPrompter.swift
//  Pawl: App Store rating asks
//
//  Decides WHEN to ask for a rating. iOS shows the rating sheet at most three times per
//  year per app and silently drops any extra request, so each ask is spent on a moment the
//  person earned: a streak milestone, a few resisted urges, a full week with Pawl on and no
//  slip, buying Pro, or setting up the hard lock with someone they trust.
//  Never on an unlock. Lifting the shield must not feel rewarding.
//
//  The views call `shouldAsk` and, on true, SwiftUI's `requestReview` environment action.
//  Never on an unlock, never on a slip, never while the cooling-off is running.
//

import Foundation

@MainActor
enum ReviewPrompter {
    enum Moment: String {
        case streakMilestone   // the home streak hero hit 7, 30, 60, 90, 180 or 365 days
        case urgeLogged        // a resisted urge was logged (third or later)
        case fullWeek          // 2.3: Home's week shows seven days on and no slip (tag: week start)
        case proPurchased      // 2.3: Pro was just bought (once ever)
        case hardLockOn        // 2.3: someone they trust set the Screen Time passcode (once ever)
    }

    static let appID = "6783119309"
    /// Deep link straight to the "Write a Review" sheet in the App Store app.
    static var writeReviewURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review")!
    }

    /// Fewest logged urges before an urge counts as a review moment.
    static let minUrgesBeforeAsk = 3

    private static let firstLaunchKey = "pawl.review.firstLaunchAt"
    private static let lastAskedKey   = "pawl.review.lastAskedAt"
    private static let askedTagsKey   = "pawl.review.askedTags"
    private static let minDaysSinceInstall = 3
    private static let minDaysBetweenAsks  = 60

    /// Starts the install clock. Safe to call every launch; only the first call writes.
    static func noteLaunch(now: Date = .now, defaults: UserDefaults = .standard) {
        if defaults.object(forKey: firstLaunchKey) == nil {
            defaults.set(now, forKey: firstLaunchKey)
        }
    }

    /// True when this moment deserves an ask right now. When it returns true the ask is
    /// recorded, so the caller must actually request the review.
    ///
    /// `tag` makes a moment one-shot: `.streakMilestone` tagged "30" asks once, ever.
    /// Untagged moments can repeat, subject to the 60-day spacing.
    @discardableResult
    static func shouldAsk(_ moment: Moment, tag: String? = nil,
                          now: Date = .now, defaults: UserDefaults = .standard) -> Bool {
        noteLaunch(now: now, defaults: defaults)
        let key = tag.map { "\(moment.rawValue)-\($0)" } ?? moment.rawValue
        var asked = defaults.stringArray(forKey: askedTagsKey) ?? []

        if tag != nil, asked.contains(key) { return false }
        if let first = defaults.object(forKey: firstLaunchKey) as? Date,
           now.timeIntervalSince(first) < Double(minDaysSinceInstall) * 86_400 { return false }
        if let last = defaults.object(forKey: lastAskedKey) as? Date,
           now.timeIntervalSince(last) < Double(minDaysBetweenAsks) * 86_400 { return false }

        asked.append(key)
        defaults.set(asked, forKey: askedTagsKey)
        defaults.set(now, forKey: lastAskedKey)
        return true
    }

    /// Delay before showing the sheet, so it does not collide with a screen transition or
    /// the "logged" animation. Views apply this before calling `requestReview`.
    static let askDelay: Duration = .seconds(1.5)
}
