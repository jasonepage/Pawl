// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  ShieldSetupView.swift
//  Pawl — vertical slice UI
//
//  Proves the core iOS integration end-to-end (SDS §4.1): authorize → pick targets
//  → apply shield → lift shield. This is the developer-facing slice, not the final
//  onboarding (FR-ONBOARD-* comes later). Run on a REAL DEVICE.
//

import SwiftUI
import FamilyControls

struct ShieldSetupView: View {
    @State private var auth = AuthorizationService()
    @State private var selection = FamilyActivitySelection()
    @State private var isPickerPresented = false
    @State private var shieldActive = false
    @State private var lastShieldAction: String?

    // Services are @MainActor; create once.
    private let shield = ShieldService()
    private let selectionStore = SelectionStore()

    var body: some View {
        NavigationStack {
            List {
                authorizationSection
                if auth.isApproved {
                    selectionSection
                    shieldSection
                }
                disclosureSection
            }
            .navigationTitle("Pawl · Setup")
            .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
            .onChange(of: selection) { _, newValue in
                selectionStore.save(newValue)
            }
            .onAppear {
                auth.refresh()                       // FR-AUTH-003
                selection = selectionStore.load()
                shieldActive = shield.isShielding
            }
        }
    }

    // MARK: Sections

    private var authorizationSection: some View {
        Section("1 · Screen Time access") {
            LabeledContent("Status", value: statusText)
            if !auth.isApproved {
                Button("Grant Screen Time access") {
                    Task { await auth.requestAuthorization() }   // FR-AUTH-001
                }
            }
            if let error = auth.lastErrorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                Text("If this mentions an entitlement / availability error, the Family Controls capability isn't added yet (see step 2 of the Xcode checklist), or you're on the Simulator instead of a real device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var selectionSection: some View {
        Section {
            Button("Open app & website picker") { isPickerPresented = true }
            LabeledContent("Apps", value: "\(selection.applicationTokens.count)")
            LabeledContent("Categories", value: "\(selection.categoryTokens.count)")
            LabeledContent("Websites", value: "\(selection.webDomainTokens.count)")
        } header: {
            Text("2 · Choose what to block")
        } footer: {
            Text("Apple's picker lets you add specific websites under its Web section, but it's limited — you can't freely type a domain. Reliable blocking of all betting/crypto sites needs a content filter, planned as a focused next step (FR-SHIELD-003/004).")
        }
    }

    @ViewBuilder
    private var shieldSection: some View {
        Section("3 · Shield") {
            LabeledContent("Shield") {
                Label(shieldActive ? "On" : "Off", systemImage: shieldActive ? "lock.fill" : "lock.open")
                    .foregroundStyle(shieldActive ? PawlColor.cleanText : .secondary)
                    .font(.body.weight(.medium))
            }
            Button("Apply shield") {                                // FR-SHIELD-005
                shield.apply(selection)
                shieldActive = true
                lastShieldAction = "Shield on — \(selection.applicationTokens.count) apps, \(selection.webDomainTokens.count) sites blocked."
            }
            .disabled(selectionIsEmpty)
            // Exposed here ONLY for the dev slice. In the real product, lifting is
            // gated by NFC tap + cooling-off and is never a free button (FR-SHIELD-008).
            #if DEBUG
            Button("Lift shield (dev only)", role: .destructive) {
                shield.lift()
                shieldActive = false
                lastShieldAction = "Shield lifted."
            }
            #endif
            if let lastShieldAction {
                Text(lastShieldAction).font(.footnote).foregroundStyle(.secondary)
            }
        }
        Section("4 · Unlock (NFC key + cooling-off)") {
            NavigationLink("Open unlock flow") {
                UnlockView(shield: shield, selection: selection)
            }
        }
    }

    private var disclosureSection: some View {
        Section {
            Text("Honest note: Pawl's shield can't be removed from iOS Settings — only Pawl can. But deleting the app or revoking this access still removes protection until reinstall. The only fully hard lock is a sponsor-set Screen Time passcode (Phase 3).")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Helpers

    private var selectionIsEmpty: Bool {
        selection.applicationTokens.isEmpty
            && selection.categoryTokens.isEmpty
            && selection.webDomainTokens.isEmpty
    }

    private var statusText: String {
        switch auth.status {
        case .approved: return "Approved"
        case .denied: return "Denied"
        case .notDetermined: return "Not requested"
        default: return "Unknown"
        }
    }
}

#Preview {
    ShieldSetupView()
}
