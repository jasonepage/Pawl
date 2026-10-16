// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  CustomDomainsView.swift
//  Pawl, Features (2.2)
//
//  The user's own typed website list. Adding blocks right away. Removing is an unlock
//  action, the same as removing an app: key, sponsor if linked, then the cooldown, and the
//  site stays blocked until the wait ends. There is no quick way out on purpose.
//

import SwiftUI

struct CustomDomainsView: View {
    let model: AppModel
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        List {
            addSection
            if let pending = model.pendingDomainRemoval { pendingSection(pending) }
            listSection
        }
        .navigationTitle("Specific websites")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var addSection: some View {
        Section {
            HStack {
                TextField("example.com", text: $draft, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .focused($fieldFocused)
                    .onSubmit(add)
                Button("Add", action: add)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } header: {
            Text("Add a website")
        } footer: {
            Text("Type or paste one address per line. Blocking starts right away and covers the site in Safari and inside apps.")
        }
    }

    private func pendingSection(_ pending: CustomDomainStore.PendingRemoval) -> some View {
        Section("Removal in progress") {
            ForEach(pending.domains, id: \.self) { domain in
                Text(domain).foregroundStyle(.secondary)
            }
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                LabeledContent("Still blocked for", value: countdown(to: pending.endsAt))
            }
            Button("Keep blocking these", role: .cancel) { model.cancelDomainRemoval() }
        }
    }

    private var listSection: some View {
        Section {
            if model.customDomains.isEmpty {
                Text("No websites yet.").foregroundStyle(.secondary)
            } else {
                ForEach(model.customDomains, id: \.self) { domain in
                    Text(domain)
                }
                .onDelete { offsets in
                    let targets = offsets.map { model.customDomains[$0] }
                    Task { await model.requestRemoveCustomDomains(targets) }
                }
            }
        } header: {
            Text("Blocked websites (\(model.customDomains.count))")
        } footer: {
            Text("Swipe to remove. Removing a site needs your key, your ally if you have one, and the cooling-off wait. It stays blocked until then.")
        }
    }

    private func add() {
        let text = draft
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if model.addCustomDomains(text) > 0 { draft = "" }
        fieldFocused = true
    }

    private func countdown(to endsAt: Date) -> String {
        let remaining = max(0, Int(endsAt.timeIntervalSinceNow))
        return String(format: "%d:%02d", remaining / 60, remaining % 60)
    }
}
