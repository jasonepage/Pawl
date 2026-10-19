// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  ScheduledSetViews.swift
//  Pawl, Settings (2.2)
//
//  The list of scheduled sets (inside What's blocked) and the editor for one set. A set
//  changes WHAT is blocked and WHEN, never how the shield unlocks. Making a set block less
//  goes through AppModel's gate like any other removal.
//

import SwiftUI
import FamilyControls

// MARK: - List section (used by ScheduledSetsView and BlockedItemsView)

struct ScheduledSetsSection: View {
    let model: AppModel
    @State private var showPaywall = false

    var body: some View {
        Section {
            ForEach(model.scheduledSets) { set in
                NavigationLink {
                    ScheduledSetEditor(model: model, original: set)
                } label: {
                    HStack {
                        SettingsRows.label("calendar", set.isEnabled ? .orange : .gray, set.name)
                        Spacer(minLength: 8)
                        Text(set.isEnabled ? ScheduledSetFormat.summary(set) : "Off")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            if model.scheduledSets.count < ScheduledSet.maxSets {
                if model.pro.isPro {
                    NavigationLink {
                        ScheduledSetEditor(model: model, original: nil)
                    } label: {
                        SettingsRows.label("plus", .orange, "Add a scheduled set")
                    }
                } else {
                    // 2.3: making a new set is part of Pawl Pro. Sets already made keep working,
                    // and editing or deleting them never needs Pro.
                    Button { showPaywall = true } label: {
                        HStack {
                            SettingsRows.label("plus", .orange, "Add a scheduled set")
                            Spacer(minLength: 8)
                            Text("Pro").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    .sheet(isPresented: $showPaywall) { PaywallView(pro: model.pro) }
                }
            }
            if let p = model.pendingSets {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    LabeledContent("Change applies in", value: SettingsRows.countdown(to: p.endsAt))
                }
                Button("Cancel change", role: .cancel) { model.cancelSetsChange() }
            }
        } header: {
            Text("Scheduled sets")
        } footer: {
            Text("A set blocks its apps only during its hours, like a Work set from 9 to 5, then they open on their own. Blocking more works right away. Blocking less (fewer apps, fewer hours, turning a set off, deleting it) needs your key and the wait.")
        }
    }
}

// MARK: - Editor

struct ScheduledSetEditor: View {
    let model: AppModel
    let original: ScheduledSet?

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selection = FamilyActivitySelection()
    @State private var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    @State private var start = Date()
    @State private var end = Date()
    @State private var isEnabled = true
    @State private var showPicker = false
    @State private var confirmDelete = false
    @State private var working = false
    @State private var loaded = false

    private var isNew: Bool { original == nil }
    private var draft: ScheduledSet {
        ScheduledSet(id: original?.id ?? UUID(),
                     name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                     selectionData: try? JSONEncoder().encode(selection),
                     weekdays: weekdays,
                     startMinute: ScheduledSetFormat.minutes(of: start),
                     endMinute: ScheduledSetFormat.minutes(of: end),
                     isEnabled: isEnabled)
    }
    private var selectionCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }
    private var canSave: Bool {
        !draft.name.isEmpty && selectionCount > 0 && !weekdays.isEmpty && windowMinutes >= 15
    }
    /// Length of one day's window, counting across midnight when the end is at or before the start.
    private var windowMinutes: Int {
        let s = ScheduledSetFormat.minutes(of: start), e = ScheduledSetFormat.minutes(of: end)
        return e > s ? e - s : (24 * 60 - s) + e
    }
    private var willWait: Bool {
        guard let original else { return false }
        return ScheduledSet.isLoosening(old: original, new: draft)
    }

    var body: some View {
        List {
            Section("Name") {
                TextField("Work, Evenings, Weekend", text: $name)
            }
            Section {
                Button {
                    showPicker = true
                } label: {
                    SettingsRows.value("apps.iphone", .blue, "Apps & sites", selectionCount == 0 ? "Choose" : "\(selectionCount)")
                }
            } header: {
                Text("What this set blocks")
            }
            Section {
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { day in
                        let on = weekdays.contains(day)
                        Button {
                            if on { weekdays.remove(day) } else { weekdays.insert(day) }
                        } label: {
                            Text(ScheduledSetFormat.dayLetter(day))
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .background(on ? PawlColor.brand : Color(.tertiarySystemFill))
                                .foregroundStyle(on ? Color.white : .primary)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(ScheduledSetFormat.dayName(day))
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                DatePicker("Starts", selection: $start, displayedComponents: .hourAndMinute)
                DatePicker("Ends", selection: $end, displayedComponents: .hourAndMinute)
                Toggle("On", isOn: $isEnabled)
            } header: {
                Text("When")
            } footer: {
                Text(ScheduledSetFormat.minutes(of: end) <= ScheduledSetFormat.minutes(of: start)
                     ? "Ends the next morning. Windows need at least 15 minutes."
                     : "Windows need at least 15 minutes.")
            }
            Section {
                Button {
                    Task {
                        working = true
                        await model.saveScheduledSet(draft)
                        working = false
                        dismiss()
                    }
                } label: {
                    Text(willWait ? "Save (waits for your key)" : "Save")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!canSave || working)
                if !isNew {
                    Button("Delete this set", role: .destructive) { confirmDelete = true }
                }
            } footer: {
                if willWait {
                    Text("This blocks less than before, so it needs your key and the cooling-off wait. The current set stays in effect until then.")
                }
            }
        }
        .navigationTitle(isNew ? "New set" : original?.name ?? "Set")
        .navigationBarTitleDisplayMode(.inline)
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .confirmationDialog("Delete this set?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete (waits for your key)", role: .destructive) {
                guard let original else { return }
                Task {
                    await model.requestDeleteScheduledSet(original)
                    dismiss()
                }
            }
        } message: {
            Text("Its apps stay blocked on schedule until the wait ends.")
        }
        .onAppear(perform: loadOriginal)
    }

    /// Runs once. onAppear can fire again after the app picker sheet closes, and reloading
    /// then would throw away the edits in progress.
    private func loadOriginal() {
        guard !loaded else { return }
        loaded = true
        let base = original ?? ScheduledSet(name: "")
        name = base.name
        selection = base.selection()
        weekdays = base.weekdays
        isEnabled = base.isEnabled
        start = ScheduledSetFormat.date(fromMinutes: base.startMinute)
        end = ScheduledSetFormat.date(fromMinutes: base.endMinute)
    }
}

// MARK: - Formatting helpers

enum ScheduledSetFormat {
    static func minutes(of date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func date(fromMinutes m: Int) -> Date {
        Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
    }

    static func time(_ m: Int) -> String {
        date(fromMinutes: m).formatted(date: .omitted, time: .shortened)
    }

    static func dayLetter(_ day: Int) -> String {
        ["S", "M", "T", "W", "T", "F", "S"][max(0, min(6, day - 1))]
    }

    static func dayName(_ day: Int) -> String {
        Calendar.current.weekdaySymbols[max(0, min(6, day - 1))]
    }

    /// "Mon to Fri, 9:00 AM to 5:00 PM", or "Every day", or "Sat, Sun".
    static func summary(_ set: ScheduledSet) -> String {
        let days = set.weekdays.sorted()
        let short = Calendar.current.shortWeekdaySymbols
        let dayText: String
        if days.count == 7 { dayText = "Every day" }
        else if days == [2, 3, 4, 5, 6] { dayText = "Weekdays" }
        else if days == [1, 7] { dayText = "Weekends" }
        else { dayText = days.map { short[$0 - 1] }.joined(separator: ", ") }
        return "\(dayText), \(time(set.startMinute)) to \(time(set.endMinute))"
    }
}
