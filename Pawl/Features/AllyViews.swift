// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  AllyViews.swift
//  Pawl: ally approvals screens (2.4, docs/18 sections 4.4, 4.7, 6)
//
//  Four screens:
//    AllyPage       the owner's page in Settings: invite, confirm with the key, remove
//    AllyJoinView   the sheet the ally sees after opening the invite link
//    AllyView       the ally's own screen: who they help, the open request, Approve, Not now
//    AllyWaitSheet  the owner's "waiting for Sam" sheet during a "block less" request
//
//  Copy rules: plain and respectful. "wants to unlock", never anything that reads as judgment.
//  The ally never sees what is blocked, slips, urges, notes or the streak (D5).
//

import SwiftUI
import CloudKit
import CryptoKit
import UserNotifications

// MARK: - The invite, as something the share sheet can send

/// An iCloud share link for the Ally zone. Messages, Mail or AirDrop deliver it; iOS opens
/// Pawl on the other phone when it is tapped (CKSharingSupported).
struct AllyInvite: Transferable {
    let share: CKShare
    let container: CKContainer

    static var transferRepresentation: some TransferRepresentation {
        CKShareTransferRepresentation { invite in
            .existing(invite.share, container: invite.container)
        }
    }
}

// MARK: - Owner: the Ally page (Settings)

struct AllyPage: View {
    let model: AppModel
    var onShowPaywall: () -> Void

    @State private var invite: AllyInvite?
    @State private var joined: AllyPairing?
    @State private var busy = false
    @State private var note: String?
    @State private var confirmRemove = false

    var body: some View {
        List {
            Section {
                Text("Whoever holds your key decides when Pawl can loosen. An ally can say yes from their own phone instead of handing the key over. Their yes starts the same wait a key tap starts. Your key always works, with or without an ally.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !model.pro.isPro {
                Section {
                    Button(action: onShowPaywall) {
                        SettingsRows.detail("star.fill", .yellow, "Ally approvals need Pawl Pro",
                                            "Only you need Pro. Your ally pays nothing.")
                    }
                }
            } else if let pairing = model.allyPairing {
                activeSection(pairing)
            } else if let pending = model.pendingAlly {
                pendingSection(pending)
            } else {
                inviteSection
            }

            if let note {
                Section { Text(note).font(.subheadline).foregroundStyle(.secondary) }
            }

            Section {
                Text("Your ally sees only that you are asking, and whether it is to unlock or to block less. Never what you block, your streak, slips or notes. They cannot change any setting.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Ally")
        .navigationBarTitleDisplayMode(.inline)
        .task { await checkJoined() }
        .refreshable { await checkJoined() }
        .confirmationDialog("Remove your ally?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove ally", role: .destructive) { Task { await model.removeAlly(); note = model.blockChangeMessage } }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("This applies right away. Your key still works.")
        }
    }

    // MARK: Sections

    private var inviteSection: some View {
        Section {
            if let joined {
                VStack(alignment: .leading, spacing: 10) {
                    Label("\(joined.name) joined", systemImage: "person.fill.checkmark")
                        .font(.headline)
                    Text(model.cooldownSeconds <= 0
                         ? "Use your key to make \(joined.name) your ally."
                         : "Use your key to make \(joined.name) your ally. It takes effect \(DurationText.startsIn(waitSeconds: model.cooldownSeconds)), like any change that blocks less.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await model.confirmAlly(joined); note = model.blockChangeMessage; self.joined = nil }
                    } label: {
                        Label("Use my key", systemImage: "key.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PawlBigButtonStyle(background: PawlColor.brand, foreground: .white))
                    .disabled(busy)
                }
                .padding(.vertical, 4)
            } else if let invite {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Send the invite to the person who holds your key. When they open it, Pawl asks them to join.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ShareLink(item: invite, preview: SharePreview("Be my Pawl ally")) {
                        Label("Send the invite", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PawlBigButtonStyle(background: PawlColor.brand, foreground: .white))
                    Button("Check if they joined") { Task { await checkJoined() } }
                        .disabled(busy)
                }
                .padding(.vertical, 4)
            } else {
                Button {
                    Task { await makeInvite() }
                } label: {
                    SettingsRows.detail("person.badge.plus", .green, "Invite an ally",
                                        "Needs iCloud on both phones. No account, no sign-in.")
                }
                .disabled(busy)
            }
        } header: {
            Text("Set up")
        }
    }

    private func pendingSection(_ pending: (name: String, endsAt: Date)) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label("\(pending.name) becomes your ally soon", systemImage: "hourglass")
                    .font(.headline)
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text("Active in \(SettingsRows.countdown(to: pending.endsAt))")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
                Button("Cancel. Don't add this ally", role: .destructive) {
                    Task { await model.removeAlly(); note = "Cancelled. No ally was added." }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("On the way")
        }
    }

    private func activeSection(_ pairing: AllyPairing) -> some View {
        Section {
            SettingsRows.detail("person.fill.checkmark", .green, "Your ally: \(pairing.name)",
                                "\(pairing.name) can say yes from their phone when you ask. Your key still works.")
            Button("Remove ally", role: .destructive) { confirmRemove = true }
        } header: {
            Text("Your ally")
        } footer: {
            Text("Removing an ally blocks more, so it applies right away and needs no key.")
        }
    }

    // MARK: Actions

    private func makeInvite() async {
        busy = true
        defer { busy = false }
        guard await AllyCloud.shared.isSignedIn() else {
            note = "Sign in to iCloud on this phone first (Settings, your name)."
            return
        }
        do {
            let share = try await AllyCloud.shared.share()
            invite = AllyInvite(share: share, container: AllyCloud.shared.container)
            note = nil
        } catch {
            note = "Couldn't make the invite. \(error.localizedDescription)"
        }
    }

    /// Has the ally joined? If there is an active ally, has that ally left?
    private func checkJoined() async {
        guard model.pro.isPro else { return }
        if model.allyPairing != nil {
            if let joined = try? await AllyCloud.shared.allyHasJoined(), joined == false {
                await model.allyLeft()
                note = model.blockChangeMessage
            }
            return
        }
        guard model.pendingAlly == nil else { return }
        busy = true
        defer { busy = false }
        do {
            joined = try await AllyCloud.shared.fetchAllyLink()
            if invite == nil, let share = try? await AllyCloud.shared.share() {
                invite = AllyInvite(share: share, container: AllyCloud.shared.container)
            }
        } catch AllyCloudError.noShare {
            // Nothing sent yet. Normal.
        } catch AllyCloudError.allyNotJoined {
            if invite == nil, let share = try? await AllyCloud.shared.share() {
                invite = AllyInvite(share: share, container: AllyCloud.shared.container)
            }
            note = "Nobody has joined yet."
        } catch AllyCloudError.allyIsOwner {
            note = "That invite was opened on a phone signed in to your own Apple Account. An ally needs their own."
        } catch {
            note = "Couldn't check. \(error.localizedDescription)"
        }
    }
}

// MARK: - Ally: the join sheet

/// Wraps share metadata so a sheet can present it.
struct AllyInviteItem: Identifiable {
    let id = UUID()
    let metadata: CKShare.Metadata
}

struct AllyJoinView: View {
    let model: AppModel
    let metadata: CKShare.Metadata
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var busy = false
    @State private var error: String?

    private var ownerName: String {
        metadata.share.owner.userIdentity.nameComponents?.givenName ?? "Someone"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                PawlLogoTile(size: 72)
                Text("\(ownerName) asked you to be their Pawl ally")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                Text("Pawl blocks apps \(ownerName) chose. To unlock, they need a physical key you hold, or a yes from you. When they ask, your phone shows it. You tap Approve or Not now. That's all. You never see what they block.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                TextField("Your first name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.givenName)
                    .autocorrectionDisabled()
                if let error {
                    Text(error).font(.footnote).foregroundStyle(PawlColor.dangerText).multilineTextAlignment(.center)
                }
                Button {
                    Task { await join() }
                } label: {
                    Text(busy ? "Joining…" : "Join as \(ownerName)'s ally").frame(maxWidth: .infinity)
                }
                .buttonStyle(PawlBigButtonStyle(background: PawlColor.brand, foreground: .white))
                .disabled(busy || name.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Not now") { dismiss() }
                    .disabled(busy)
                Spacer()
            }
            .padding(24)
            .navigationTitle("Be an ally")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func join() async {
        busy = true
        defer { busy = false }
        error = nil
        do {
            let (zone, owner) = try await AllyCloud.shared.acceptShare(metadata)
            let key = try AllyStore.makeSigningKey()
            let myName = String(name.trimmingCharacters(in: .whitespaces).prefix(40))
            try await AllyCloud.shared.writeAllyLink(publicKey: key.publicKey.x963Representation, name: myName, zone: zone)
            let role = AllyRole(signingKeyBlob: key.dataRepresentation, myName: myName,
                                ownerName: owner.isEmpty ? ownerName : owner, zone: zone, joinedAt: Date())
            model.setAllyRole(role)
            try? await AllyCloud.shared.subscribeAlly(ownerName: myName.isEmpty ? "Someone" : (owner.isEmpty ? ownerName : owner))
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            UIApplication.shared.registerForRemoteNotifications()
            dismiss()
        } catch {
            self.error = "Couldn't join. \(error.localizedDescription)"
        }
    }
}

// MARK: - Ally: their screen

struct AllyView: View {
    let model: AppModel
    /// Shown when this phone is only an ally (no blocking of its own).
    var onSetUpOwn: (() -> Void)? = nil

    @State private var request: AllyRequest?
    @State private var busy = false
    @State private var note: String?
    @State private var answered: Bool? = nil     // true yes, false no, nil nothing yet
    @State private var confirmLeave = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    if let role = model.allyRole {
                        header(role)
                        if let request {
                            requestCard(request, role: role)
                        } else {
                            quietCard(role)
                        }
                        if let note {
                            Text(note).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        Button("Stop being \(role.ownerName)'s ally", role: .destructive) { confirmLeave = true }
                            .padding(.top, 12)
                        if let onSetUpOwn {
                            Button("Set up Pawl for yourself too", action: onSetUpOwn)
                                .font(.subheadline)
                        }
                    }
                }
                .padding(20)
            }
            .background(PawlColor.groupedBg)
            .navigationTitle("Ally")
            .task { await refreshLoop() }
            .refreshable { await refresh() }
            .onReceive(NotificationCenter.default.publisher(for: .pawlAllyCloudChanged)) { _ in
                Task { await refresh() }
            }
            .confirmationDialog("Stop being an ally?", isPresented: $confirmLeave, titleVisibility: .visible) {
                Button("Stop", role: .destructive) { Task { await model.leaveAllyRole() } }
                Button("Keep helping", role: .cancel) {}
            } message: {
                Text("They keep their key and can still unlock with it. They will see that you left.")
            }
        }
        .tint(PawlColor.brand)
    }

    private func header(_ role: AllyRole) -> some View {
        VStack(spacing: 8) {
            PawlStateGlyph(symbol: request != nil ? "hourglass" : "person.2.fill", size: 48)
            Text("You're \(role.ownerName)'s ally")
                .font(.system(.title2, design: .rounded).weight(.bold))
            Text("When \(role.ownerName) asks, it shows here. Approve starts their wait, the same as their key would. Not now leaves things as they are.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func quietCard(_ role: AllyRole) -> some View {
        PawlCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("Nothing to answer").font(.headline)
                Text("No open request from \(role.ownerName).").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func requestCard(_ request: AllyRequest, role: AllyRole) -> some View {
        PawlCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(request.kind == .unlock
                     ? "\(role.ownerName) wants to unlock Pawl."
                     : "\(role.ownerName) wants to block less in Pawl.")
                    .font(.headline)
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text("Asked \(request.createdAt.formatted(date: .omitted, time: .shortened)). Expires in \(SettingsRows.countdown(to: request.expiresAt)).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Button {
                    Task { await answer(true, request, role) }
                } label: {
                    Label("Approve", systemImage: "checkmark").frame(maxWidth: .infinity)
                }
                .buttonStyle(PawlBigButtonStyle(background: PawlColor.brand, foreground: .white))
                .disabled(busy)
                Button {
                    Task { await answer(false, request, role) }
                } label: {
                    Text("Not now").frame(maxWidth: .infinity)
                }
                .buttonStyle(PawlBigButtonStyle(background: PawlColor.cardBg, foreground: .primary))
                .disabled(busy)
            }
        }
    }

    // MARK: Actions

    private func refreshLoop() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: .seconds(10))
        }
    }

    private func refresh() async {
        guard let role = model.allyRole else { return }
        do {
            let open = try await AllyCloud.shared.fetchOpenRequest(zone: role.zone)
            // An expired request is nothing to answer.
            request = (open.map { $0.expiresAt >= Date() } ?? false) ? open : nil
            if request != nil { answered = nil }
        } catch let e as CKError where e.code == .zoneNotFound || e.code == .unknownItem || e.code == .participantMayNeedVerification {
            // The owner removed this ally (the zone is gone).
            request = nil
            note = "\(role.ownerName) ended the ally link. Nothing more to do here."
        } catch {
            note = "Couldn't check right now."
        }
    }

    private func answer(_ approved: Bool, _ request: AllyRequest, _ role: AllyRole) async {
        busy = true
        defer { busy = false }
        do {
            guard let key = try AllyStore.shared.signingKey() else { note = "This phone's ally key is missing."; return }
            // Signing asks for Face ID, Touch ID or the passcode.
            let decision = try AllyDecisionVerifier.makeDecision(for: request, approved: approved, now: Date()) {
                try key.signature(for: $0)
            }
            try await AllyCloud.shared.writeDecision(decision, zone: role.zone)
            self.request = nil
            answered = approved
            note = approved ? "Sent. \(role.ownerName)'s wait starts now." : "Sent. Nothing changes for \(role.ownerName)."
        } catch {
            note = "Couldn't send that. \(error.localizedDescription)"
        }
    }
}

// MARK: - Owner: waiting on a "block less" answer

struct AllyWaitSheet: View {
    let wait: AppModel.AllyWait
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            PawlStateGlyph(symbol: "hourglass", size: 56)
            Text("Asking \(wait.name)")
                .font(.system(.title2, design: .rounded).weight(.bold))
            Text("Nothing changes until \(wait.name) says yes. You can also use your key instead.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Text("Request expires in \(SettingsRows.countdown(to: wait.expiresAt))")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            Button {
                onCancel()
            } label: {
                Text("Cancel. Keep things as they are").frame(maxWidth: .infinity)
            }
            .buttonStyle(PawlBigButtonStyle(background: PawlColor.cardBg, foreground: .primary))
        }
        .padding(28)
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }
}
