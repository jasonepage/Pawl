// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  UnlockReminders.swift
//  Pawl — 2.3
//
//  Local reminders around an unlock, scheduled on the phone when the wait starts. Nothing goes
//  to a server (2.3 has none). Plain words, no cheering: a heads-up before apps open (with a
//  reminder that cancelling is still possible), when they open, and before they lock again.
//
//  Permission is asked the first time someone starts an unlock, which is when the reminders
//  mean something. If they say no, unlocking works exactly the same, just without reminders.
//

import Foundation
import UserNotifications

@MainActor
enum UnlockReminders {
    private static let idPrefix = "pawl.unlock."

    struct Reminder: Equatable {
        let id: String
        let at: Date
        let title: String
        let body: String
    }

    /// The reminders for an unlock whose wait ends at `opensAt` and whose open time ends at
    /// `locksAt`. Only ones still in the future, at least 30 seconds out. Pure, so it's tested.
    nonisolated static func plan(opensAt: Date, locksAt: Date, now: Date,
                                 timeText: (Date) -> String) -> [Reminder] {
        let all = [
            Reminder(id: idPrefix + "open5", at: opensAt.addingTimeInterval(-5 * 60),
                     title: "Apps open in 5 minutes",
                     body: "You can still cancel in Pawl and keep them locked."),
            Reminder(id: idPrefix + "open1", at: opensAt.addingTimeInterval(-60),
                     title: "Apps open in 1 minute",
                     body: "Still time to cancel and keep them locked."),
            Reminder(id: idPrefix + "open0", at: opensAt,
                     title: "Your apps are open",
                     body: "They lock again at \(timeText(locksAt))."),
            Reminder(id: idPrefix + "lock5", at: locksAt.addingTimeInterval(-5 * 60),
                     title: "Apps lock again in 5 minutes",
                     body: "Wrap up what you're doing."),
            Reminder(id: idPrefix + "lock1", at: locksAt.addingTimeInterval(-60),
                     title: "Apps lock again in 1 minute",
                     body: "Pawl will lock them on its own."),
            Reminder(id: idPrefix + "lock0", at: locksAt,
                     title: "Apps are locked again",
                     body: "Opening them takes your key and the wait again."),
        ]
        return all.filter { $0.at.timeIntervalSince(now) >= 30 }
    }

    /// Schedule reminders for an unlock that just started. Replaces any earlier set.
    static func schedule(opensAt: Date, locksAt: Date) async {
        let center = UNUserNotificationCenter.current()
        cancel()
        let allowed = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard allowed else { return }
        let reminders = plan(opensAt: opensAt, locksAt: locksAt, now: Date()) {
            $0.formatted(date: .omitted, time: .shortened)
        }
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            content.threadIdentifier = "pawl.unlock"
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                                        from: reminder.at)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
    }

    /// Remove every reminder that hasn't been shown yet (the unlock was cancelled).
    static func cancel() {
        let ids = ["open5", "open1", "open0", "lock5", "lock1", "lock0"].map { idPrefix + $0 }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}
