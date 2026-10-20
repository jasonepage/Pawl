// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  UnlockReminders.swift
//  Pawl, 2.3
//
//  Local reminders around an unlock, scheduled on the phone when the wait starts. Nothing goes
//  to a server (2.3 has none). Plain words, no cheering: a heads-up before apps open (with a
//  reminder that cancelling is still possible), when they open, and before they lock again.
//
//  Permission is asked the first time someone starts an unlock, which is when the reminders
//  mean something. If they say no, unlocking works exactly the same, just without reminders.
//
//  The reminders must always match what is really happening. So:
//  - Cancelling the wait removes them, even if the cancel lands while they are still being
//    added (for example while the permission prompt is up). A generation number catches that.
//  - If the open time starts at a different moment than planned, the lock reminders move to
//    the real lock time and any "apps open" reminders still waiting are dropped.
//  - If apps lock early, or Pawl finds nothing unlocking, every reminder still in the future
//    is dropped. One due within the next few seconds is kept, so the normal "Apps are locked
//    again" still arrives on time.
//

import Foundation
import UserNotifications

@MainActor
enum UnlockReminders {
    private static let idPrefix = "pawl.unlock."
    private static let openIDs = ["open5", "open1", "open0"].map { idPrefix + $0 }
    private static let lockIDs = ["lock5", "lock1", "lock0"].map { idPrefix + $0 }
    private static var allIDs: [String] { openIDs + lockIDs }

    /// Reminders due this close to now are left alone when clearing, so the one that matches
    /// the moment that just happened still shows.
    nonisolated static let keepWithin: TimeInterval = 5

    /// Bumped by every schedule and every clear. Work that started under an older number stops
    /// and removes what it added.
    private static var generation = 0

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

    /// Which pending reminders to remove when the unlock ended or changed early: Pawl's own
    /// reminders (only those in `ids`) that are more than `keepWithin` seconds away. Pure, so
    /// it's tested.
    nonisolated static func idsToClear(pending: [(id: String, fireDate: Date?)], ids: [String],
                                       now: Date) -> [String] {
        pending.compactMap { item in
            guard ids.contains(item.id) else { return nil }
            guard let fire = item.fireDate else { return item.id }   // no next date: stale
            return fire.timeIntervalSince(now) > keepWithin ? item.id : nil
        }
    }

    /// Schedule reminders for an unlock that just started. Replaces any earlier set.
    static func schedule(opensAt: Date, locksAt: Date) async {
        generation += 1
        let mine = generation
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: allIDs)
        let allowed = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard allowed, mine == generation else { return }   // cancelled while the prompt was up
        let reminders = plan(opensAt: opensAt, locksAt: locksAt, now: Date(), timeText: timeText)
        await add(reminders, generation: mine)
    }

    /// The open time started at `locksAt` minus the open length, maybe not when planned (for
    /// example the developer "skip the wait" button). Move the lock reminders to the real lock
    /// time and drop "apps open" reminders that are still waiting. In a normal unlock the times
    /// already match, so this changes nothing. Never asks for permission.
    static func moveLockReminders(to locksAt: Date) async {
        generation += 1
        let mine = generation
        let center = UNUserNotificationCenter.current()
        await clear(ids: openIDs)
        guard mine == generation else { return }
        let status = await center.notificationSettings().authorizationStatus
        guard mine == generation, status == .authorized || status == .provisional else { return }
        let lockOnly = plan(opensAt: .distantPast, locksAt: locksAt, now: Date(), timeText: timeText)
            .filter { lockIDs.contains($0.id) }
        await add(lockOnly, generation: mine)
    }

    /// Apps locked again, or Pawl found no unlock in progress: drop every reminder that is
    /// still in the future, keeping only one due within the next few seconds.
    static func clearUpcoming() async {
        generation += 1
        await clear(ids: allIDs)
    }

    /// The wait was cancelled: remove every reminder, right away.
    static func cancel() {
        generation += 1
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: allIDs)
    }

    // MARK: - Helpers

    nonisolated private static func timeText(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private static func clear(ids: [String]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map { request in
            (id: request.identifier,
             fireDate: (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate())
        }
        let remove = idsToClear(pending: pending, ids: ids, now: Date())
        if !remove.isEmpty { center.removePendingNotificationRequests(withIdentifiers: remove) }
    }

    /// Add reminders one by one. If a cancel or clear lands between two adds, stop and take
    /// back what this run added, so nothing stale is left behind.
    private static func add(_ reminders: [Reminder], generation mine: Int) async {
        let center = UNUserNotificationCenter.current()
        var added: [String] = []
        for reminder in reminders {
            guard mine == generation else { break }
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            content.threadIdentifier = "pawl.unlock"
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                                        from: reminder.at)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
            added.append(reminder.id)
        }
        if mine != generation, !added.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: added)
        }
    }
}
