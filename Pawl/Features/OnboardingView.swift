// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  OnboardingView.swift
//  Pawl — first-run flow
//
//  Honest, staged onboarding (FR-ONBOARD-001/002/003): explain → authorize → choose
//  targets → pair key → activate. Themed for calm + accessibility.
//

import SwiftUI
import FamilyControls
import AuthenticationServices

struct OnboardingView: View {
    let model: AppModel

    @State private var role: AppRole?          // nil → show the role/focus picker first
    @State private var vertical: Vertical = .gambling   // what the user is here to quit
    @State private var codeEntry = ""
    @State private var step = 0
    @State private var selection = FamilyActivitySelection()
    @State private var blockGambling = true     // gambling is the default category (D6)
    @State private var blockAdult = false
    @State private var isPickerPresented = false
    @State private var keyPaired = false
    @State private var pairLater = false        // "I don't have a key yet" → set up now, pair later
    @State private var working = false
    @State private var message: String?

    private let security = SecurityKeyService()
    private let keyStore = KeyStore()

    private let totalSteps = 5

    var body: some View {
        Group {
            if role == nil {
                rolePicker
            } else if role == .approver {
                approverFlow
            } else {
                blockerFlow
            }
        }
        .frame(maxWidth: 600)              // keep a readable centered column on iPad
        .frame(maxWidth: .infinity)        // …with the background still filling the screen
        .background(PawlColor.groupedBg)
        .tint(PawlColor.brand)
    }

    // MARK: Role picker (first screen)

    private var rolePicker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heading("Welcome to Pawl", "What brings you here?")
                body("Choose what you want to quit — Pawl blocks it and makes unblocking deliberately hard. Or set up as an approver to support someone else.")
                VStack(spacing: 12) {
                    ForEach(Vertical.allCases, id: \.self) { v in
                        Button { chooseFocus(v) } label: {
                            roleCard(v.icon, v.title, v.cardSubtitle)
                        }
                    }
                    Button { role = .approver } label: {
                        roleCard("checkmark.shield",
                                 "I'm supporting someone",
                                 "You won't block anything. You'll approve their unlocks and get alerts.")
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
    }

    /// Pick a focus → become a blocker and preset the default website categories for that focus.
    /// The user can still adjust the toggles (multi-select) on the categories step.
    private func chooseFocus(_ v: Vertical) {
        vertical = v
        blockGambling = v.defaultBlockGambling
        blockAdult = v.defaultBlockAdult
        role = .blocker
    }

    /// A small icon + title + explanation row — used by the "what's a security key?" explainer.
    private func infoRow(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline).foregroundStyle(PawlColor.brand).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.caption).foregroundStyle(.secondary).lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func roleCard(_ icon: String, _ title: String, _ sub: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title).foregroundStyle(PawlColor.brand).frame(width: 38)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title3.weight(.semibold)).foregroundStyle(.primary)
                Text(sub).font(.callout).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Approver flow (sign in + invite code, no blocking)

    private var approverFlow: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heading("Approver setup", model.account.isSignedIn ? "Almost done." : "Sign in to approve.")
                body("You won't block anything on your own phone. You'll approve unlock requests from the person you're supporting — and get alerted if their protection drops.")

                if !model.account.isSignedIn {
                    SignInWithAppleButton(.signIn) { request in
                        model.account.configure(request)
                    } onCompletion: { result in
                        Task { await model.account.handle(result) }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                } else {
                    body("Enter the invite code they shared with you. You can also add it later in the app.")
                    TextField("Invite code", text: $codeEntry)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.title3, design: .monospaced).weight(.medium))
                        .tracking(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(PawlColor.brand.opacity(codeEntry.isEmpty ? 0.0 : 0.6), lineWidth: 1.5)
                        )
                    secondary("Link with this code") {
                        Task { await model.sponsor.redeem(code: codeEntry); codeEntry = "" }
                    }
                    .disabled(codeEntry.isEmpty)
                    if model.sponsor.asSponsor.contains(where: { $0.status == "active" }) {
                        Text("Linked ✓").font(.headline).foregroundStyle(PawlColor.brand)
                    }
                    if let m = model.sponsor.message {
                        Text(m).font(.footnote).foregroundStyle(.secondary)
                    }
                    primary("Done") { model.completeAsApprover() }
                }

                Button("← Back") { role = nil }
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(20)
        }
    }

    // MARK: Blocker flow (the full setup)

    private var blockerFlow: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(step + 1), total: Double(totalSteps))
                .tint(PawlColor.brand)
                .padding(.horizontal, 20)
                .padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    content
                    if let message {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }

            footer
                .padding(20)
        }
        .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
    }

    // MARK: Step content

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0:
            heading("Welcome to Pawl", "The catch that won't let you slip back.")
            body(vertical.welcomeBody)
        case 1:
            heading("Allow Screen Time", "This is how Pawl blocks apps.")
            body("Pawl uses Apple's Screen Time to shield apps and sites. We only ever see anonymous tokens — never which specific apps you chose.")
            LabeledContent("Status", value: model.auth.isApproved ? "Approved" : "Not yet")
                .font(.headline)
            if let err = model.auth.lastErrorMessage {
                Text(err).font(.footnote).foregroundStyle(.red)
            }
        case 2:
            heading(categoryStepTitle, categoryStepSubtitle)
            categoryToggle(title: "Gambling sites",
                           subtitle: "Sportsbook, casino, and crypto sites we keep a list of.",
                           isOn: $blockGambling)
            categoryToggle(title: "Adult sites",
                           subtitle: "Turns on Apple's built-in adult-website filter.",
                           isOn: $blockAdult)
            body("Website categories apply automatically. To also lock specific apps — the ones you keep opening — add them below. That part's optional.")
            LabeledContent("Apps added", value: "\(selection.applicationTokens.count)")
                .font(.headline)
        case 3:
            heading("Pair your key", keyHeadlineSub)
            if keyPaired {
                body("Now put the key out of reach — give it to a sponsor or lock it in a timebox. That distance is the whole point.")
            } else if pairLater {
                body("No problem — set up Pawl now and pair your key when it arrives.")
                VStack(alignment: .leading, spacing: 14) {
                    infoRow("cart.fill", "Get a USB-C security key",
                            "Any FIDO2 USB-C key works. Search \u{201C}FIDO2 USB-C security key,\u{201D} or look at the YubiKey 5C or Google Titan — about $30.")
                    infoRow("lock.shield", "Your blocks turn on now",
                            "Pawl starts protecting you right away. Until a key is paired you can't unblock from inside Pawl, so pair it as soon as it arrives.")
                    infoRow("arrow.clockwise", "Pair it anytime",
                            "Open the Unlock tab and tap \u{201C}Pair security key\u{201D} once you have it in hand. The first pairing is free.")
                }
                .padding(.top, 2)
            } else {
                body("A security key is a small physical device — about the size of a USB stick — that proves it's really you. It's the same kind of key banks and Google use for their strongest account protection.")
                VStack(alignment: .leading, spacing: 14) {
                    infoRow("key.fill", "It's your only unlock",
                            "Pawl lifts the shield only when this exact key is connected. No key in hand, no unblock — that's the whole idea.")
                    infoRow("cable.connector", "It plugs into your iPhone",
                            "Use a USB-C security key (the FIDO2 kind). You can buy one for about $30 — YubiKey and Google Titan are common ones.")
                    infoRow("shippingbox.fill", "Where you keep it is the trick",
                            "Because unblocking needs the physical key, you give it to someone you trust or lock it away — so it's never in your pocket at 1am.")
                }
                .padding(.top, 2)
                body("Have your key handy and plug it in, then tap Pair below.")
            }
        default:
            heading("Lock it in", "You're about to activate Pawl.")
            body("We'll turn on your protection now — the website categories you chose, plus any apps you added. From here, lifting the shield needs your key + a 15-minute cooling-off. Turning off Screen Time can still remove protection (and alerts your sponsor) — the only fully hard lock is a sponsor-set Screen Time passcode (a later step).")
        }
    }

    // MARK: Footer button

    @ViewBuilder
    private var footer: some View {
        switch step {
        case 0:
            primary("Get started") { step = 1 }
        case 1:
            if model.auth.isApproved {
                primary("Continue") { step = 2 }
            } else {
                primary("Allow Screen Time") {
                    Task { await model.auth.requestAuthorization() }
                }
            }
        case 2:
            VStack(spacing: 10) {
                secondary(selection.applicationTokens.isEmpty ? "Add apps (optional)" : "Edit apps") {
                    isPickerPresented = true
                }
                primary(selectionIsEmpty ? "Continue without apps" : "Continue") { step = 3 }
                    .disabled(nothingSelected)
                    .opacity(nothingSelected ? 0.5 : 1)
                if nothingSelected {
                    Text("Pick at least one category, or add an app, so Pawl protects something.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        case 3:
            VStack(spacing: 10) {
                if !pairLater {
                    secondary(keyPaired ? "Re-pair key" : "Pair security key") {
                        Task { await pairKey() }
                    }
                    .disabled(working)
                }
                primary("Continue") { step = 4 }
                    .disabled(!(keyPaired || pairLater))
                    .opacity((keyPaired || pairLater) ? 1 : 0.5)
                if !keyPaired {
                    Button(pairLater ? "Actually, I'll pair a key now" : "I don't have a key yet") {
                        pairLater.toggle()
                    }
                    .font(.footnote)
                    .foregroundStyle(PawlColor.brand)
                    .padding(.top, 2)
                }
            }
        default:
            primary(working ? "Activating…" : "Lock it in") {
                Task {
                    working = true
                    model.setWebCategories(gambling: blockGambling, adult: blockAdult)
                    await model.activate(selection: selection, vertical: vertical)   // flips didOnboard → main app
                }
            }
            .disabled(working)
        }
    }

    // MARK: Pieces

    private func heading(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.largeTitle.bold())
            Text(sub).font(.title3).foregroundStyle(PawlColor.cleanText)
        }
        .padding(.top, 8)
    }

    private func body(_ text: String) -> some View {
        Text(text).font(.body).foregroundStyle(.secondary).lineSpacing(3)
    }

    private func primary(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(label) }
            .buttonStyle(PawlBigButtonStyle(background: PawlColor.cleanBg, foreground: PawlColor.cleanText))
    }

    private func secondary(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(label).frame(maxWidth: .infinity).padding(.vertical, 14) }
            .buttonStyle(.bordered)
    }

    private var selectionIsEmpty: Bool {
        selection.applicationTokens.isEmpty
            && selection.categoryTokens.isEmpty
            && selection.webDomainTokens.isEmpty
    }

    /// Nothing to protect: no website category and no apps.
    private var nothingSelected: Bool {
        !blockGambling && !blockAdult && selectionIsEmpty
    }

    /// Categories-step copy, tailored to the chosen focus.
    private var categoryStepTitle: String {
        vertical == .custom ? "Choose what to block" : "What are you here to block?"
    }
    private var categoryStepSubtitle: String {
        switch vertical {
        case .custom:       return "Add the apps you keep reaching for — websites are optional."
        case .adultContent: return "Adult sites are on. Add apps, or gambling sites, too if you want."
        case .gambling:     return "Pick one or both — Pawl handles the websites."
        }
    }

    /// Subtitle on the key step: paired / get-one-later / explainer.
    private var keyHeadlineSub: String {
        if keyPaired { return "Paired ✓" }
        return pairLater ? "No key yet? That's OK." : "What's a security key?"
    }

    /// A filled, tappable category card with a toggle, matching the app's card style.
    private func categoryToggle(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .tint(PawlColor.brand)
        .padding(14)
        .background(PawlColor.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func pairKey() async {
        message = nil
        working = true
        defer { working = false }
        do {
            let credentialID = try await security.register(displayName: "Pawl key")
            keyStore.save(credentialID.base64EncodedString())
            keyPaired = true
        } catch {
            message = error.localizedDescription
        }
    }
}

#Preview {
    OnboardingView(model: AppModel())
}
