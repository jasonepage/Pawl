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

struct OnboardingView: View {
    let model: AppModel

    @State private var role: AppRole?          // nil → show the role/focus picker first
    @State private var vertical: Vertical = .custom     // set when the person picks a focus
    @State private var pickedFocus: Vertical?            // 2.2: nothing selected until they choose
    @State private var hoursPerDay: Double = 2           // welcome-screen estimate, never stored
    @State private var step = 0
    @State private var selection = FamilyActivitySelection()
    @State private var blockGambling = true     // gambling is the default category (D6)
    @State private var blockAdult = false
    @State private var isPickerPresented = false
    @State private var keyPaired = false
    @State private var pairLater = false        // "I don't have a key yet" → set up now, pair later
    @State private var working = false
    @State private var message: String?
    @State private var siteEntry = ""            // 2.2: typed websites, added right from setup

    private let security = SecurityKeyService()
    private let keyStore = KeyStore()

    private let totalSteps = 5

    var body: some View {
        Group {
            if role == nil {
                rolePicker
            } else {
                blockerFlow
            }
        }
        .frame(maxWidth: 600)              // keep a readable centered column on iPad
        .frame(maxWidth: .infinity)        // …with the background still filling the screen
        .background(PawlColor.groupedBg)
        .tint(PawlColor.brand)
        .task { await model.noteSetupStarted() }
    }

    // MARK: Role picker (first screen)

    private var rolePicker: some View {
        ScrollView {
            VStack(spacing: 22) {
                PawlArt("shield.lefthalf.filled", size: 110)
                    .padding(.top, 24)
                VStack(spacing: 6) {
                    Text("Welcome to Pawl")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    Text("What do you want to block?")
                        .font(.title3)
                        .foregroundStyle(PawlColor.cleanText)
                }
                .multilineTextAlignment(.center)
                Text("Pick one to start. You can add more later.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                          spacing: 12) {
                    ForEach(Vertical.allCases, id: \.self) { v in
                        Button { pickedFocus = v } label: {
                            focusCard(v, selected: pickedFocus == v)
                        }
                        .buttonStyle(.plain)
                    }
                }

                primary("Continue") { if let v = pickedFocus { chooseFocus(v) } }
                    .disabled(pickedFocus == nil)
                    .opacity(pickedFocus == nil ? 0.5 : 1)
            }
            .padding(20)
        }
    }

    /// One focus choice: icon on top, title, one short line. Selected gets the green fill.
    private func focusCard(_ v: Vertical, selected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle().fill(selected ? PawlColor.brand : PawlColor.cleanBg)
                Image(systemName: v.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(selected ? Color.white : PawlColor.brand)
            }
            .frame(width: 44, height: 44)
            Text(v.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(v.cardSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(selected ? PawlColor.cleanBg : PawlColor.cardBg)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(selected ? PawlColor.brand : .clear, lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Become a blocker and preset the website categories for the chosen focus. Only gambling
    /// and adult content have a website preset; the app picker cannot be pre-filled (Apple
    /// hands Pawl opaque tokens), so every other focus starts with the picker on the next step.
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

    // MARK: Blocker flow (the full setup)

    private var blockerFlow: some View {
        VStack(spacing: 0) {
            PawlStepDots(current: step, total: totalSteps)
                .padding(.top, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    content
                    if let message {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
            art("hourglass")
            heading("What it costs you", "A quick, private look.")
            body(vertical.welcomeBody)
            card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("How many hours a day does this take?")
                        .font(.headline)
                    HStack {
                        Slider(value: $hoursPerDay, in: 0...8, step: 0.5)
                        Text(hoursPerDay == hoursPerDay.rounded() ? "\(Int(hoursPerDay)) h" : String(format: "%.1f h", hoursPerDay))
                            .font(.body.monospacedDigit())
                            .frame(width: 44, alignment: .trailing)
                    }
                    if let line = TimeCost.sentence(hoursPerDay: hoursPerDay) {
                        Text(line)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(PawlColor.cleanText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Stays on your phone. Pawl uses it to show you the time you keep.")
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }
        case 1:
            art("hand.raised.fill")
            heading("Allow Screen Time", "This is how Pawl blocks apps.")
            body("Apple's Screen Time does the blocking. Pawl only ever sees anonymous tokens, never which apps you chose.")
            card {
                HStack {
                    Image(systemName: model.auth.isApproved ? "checkmark.circle.fill" : "circle.dashed")
                        .font(.title2)
                        .foregroundStyle(model.auth.isApproved ? PawlColor.brand : Color.secondary)
                    Text(model.auth.isApproved ? "Screen Time allowed" : "Not allowed yet")
                        .font(.headline)
                    Spacer(minLength: 0)
                }
            }
            if let err = model.auth.lastErrorMessage {
                Text(err).font(.footnote).foregroundStyle(.red)
            }
        case 2:
            art("checklist")
            heading(categoryStepTitle, categoryStepSubtitle)
            categoryToggle(title: "Gambling sites",
                           subtitle: "Sportsbook, casino, and crypto sites we keep a list of.",
                           isOn: $blockGambling)
            categoryToggle(title: "Adult sites",
                           subtitle: "Turns on Apple's built-in adult-website filter.",
                           isOn: $blockAdult)
            card {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apps").font(.headline)
                        Text(selection.applicationTokens.isEmpty
                             ? "None added yet"
                             : (selection.applicationTokens.count == 1 ? "1 app added" : "\(selection.applicationTokens.count) apps added"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Button(selection.applicationTokens.isEmpty ? "Add" : "Edit") { isPickerPresented = true }
                        .buttonStyle(.bordered)
                }
            }
            card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Websites").font(.headline)
                    Text("Type a site to block it, like example.com.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        TextField("example.com", text: $siteEntry)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .submitLabel(.done)
                            .onSubmit(addTypedSite)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        Button("Add", action: addTypedSite)
                            .buttonStyle(.bordered)
                            .disabled(siteEntry.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if !model.customDomains.isEmpty {
                        Text(model.customDomains.sorted().joined(separator: ", "))
                            .font(.footnote)
                            .foregroundStyle(PawlColor.cleanText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let m = model.blockChangeMessage {
                        Text(m).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        case 3:
            art(keyPaired ? "checkmark.seal.fill" : "key.fill")
            heading("Pair your key", keyHeadlineSub)
            if keyPaired {
                body("Now put the key out of reach. Give it to someone you trust or lock it in a drawer somewhere else. That distance is the whole point.")
            } else if pairLater {
                body("No problem. Set up Pawl now and pair your key when it arrives.")
                card {
                    VStack(alignment: .leading, spacing: 14) {
                        infoRow("cart.fill", "Get a USB-C security key",
                                "Any FIDO2 USB-C key works. Search \u{201C}FIDO2 USB-C security key,\u{201D} or look at the YubiKey 5C or Google Titan, about $30.")
                        infoRow("lock.shield", "Your blocks turn on now",
                                "Pawl starts protecting you right away. Until a key is paired you can't unblock from inside Pawl, so pair it as soon as it arrives.")
                        infoRow("arrow.clockwise", "Pair it anytime",
                                "Open the Unlock tab and tap \u{201C}Pair security key\u{201D} once you have it in hand. The key becomes active after your cooling-off wait.")
                    }
                }
            } else {
                body("A security key is a small device, about the size of a USB stick, that proves it's really you. Banks and Google use the same kind for their strongest protection.")
                card {
                    VStack(alignment: .leading, spacing: 14) {
                        infoRow("key.fill", "It's your only unlock",
                                "Pawl lifts the shield only when this exact key is connected. No key in hand, no unblock.")
                        infoRow("cable.connector", "It plugs into your iPhone",
                                "Use a USB-C security key (the FIDO2 kind), about $30. YubiKey and Google Titan are common ones.")
                        infoRow("shippingbox.fill", "Where you keep it is the trick",
                                "You give it to someone you trust or lock it away, so it's never in your pocket at 1am.")
                    }
                }
                body("Have your key handy and plug it in, then tap Pair below.")
            }
        default:
            art("lock.fill")
            heading("Lock it in", "Here's what you're turning on.")
            card {
                VStack(alignment: .leading, spacing: 12) {
                    summaryRow("globe", "Website categories", categorySummary)
                    summaryRow("apps.iphone", "Apps",
                               selection.applicationTokens.isEmpty ? "None" : "\(selection.applicationTokens.count)")
                    summaryRow("link", "Typed sites",
                               model.customDomains.isEmpty ? "None" : "\(model.customDomains.count)")
                    summaryRow("key.fill", "Security key", keyPaired ? "Paired" : "Pair later")
                    summaryRow("hourglass", "Unlock wait", "15 minutes")
                }
            }
            body("From here, lifting the shield needs your key plus the wait. Turning off Screen Time still removes protection. For a full lock, someone you trust can set a Screen Time passcode for you. That's Hard lock in Settings.")
        }
    }

    private var categorySummary: String {
        switch (blockGambling, blockAdult) {
        case (true, true):   return "Gambling, Adult"
        case (true, false):  return "Gambling"
        case (false, true):  return "Adult"
        case (false, false): return "None"
        }
    }

    private func addTypedSite() {
        let text = siteEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if model.addCustomDomains(text) > 0 { siteEntry = "" }
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
                primary("Continue") { step = 3 }
                    .disabled(nothingSelected)
                    .opacity(nothingSelected ? 0.5 : 1)
                if nothingSelected {
                    Text("Pick a category, add an app, or type a site, so Pawl protects something.")
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
                    model.setOnboardingWebCategories(gambling: blockGambling, adult: blockAdult)
                    model.hoursPerDay = hoursPerDay
                    await model.activate(selection: selection, vertical: vertical)   // flips didOnboard → main app
                }
            }
            .disabled(working)
        }
    }

    // MARK: Pieces

    private func heading(_ title: String, _ sub: String) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.system(.largeTitle, design: .rounded).weight(.bold))
            Text(sub).font(.title3).foregroundStyle(PawlColor.cleanText)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func art(_ symbol: String) -> some View {
        PawlArt(symbol, size: 100)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        PawlCard(content: content)
    }

    private func summaryRow(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline).foregroundStyle(PawlColor.brand).frame(width: 26)
            Text(title).font(.body)
            Spacer(minLength: 8)
            Text(value).font(.body.weight(.semibold)).multilineTextAlignment(.trailing)
        }
    }

    private func body(_ text: String) -> some View {
        Text(text).font(.body).foregroundStyle(.secondary).lineSpacing(3)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
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

    /// Nothing to protect: no website category, no apps, no typed sites.
    private var nothingSelected: Bool {
        !blockGambling && !blockAdult && selectionIsEmpty && model.customDomains.isEmpty
    }

    /// Categories-step copy, tailored to the chosen focus.
    private var categoryStepTitle: String {
        switch vertical {
        case .gambling, .adultContent: return "What are you here to block?"
        default:                       return "Choose what to block"
        }
    }
    private var categoryStepSubtitle: String {
        switch vertical {
        case .social:       return "Add the social apps you keep opening. Website categories are optional."
        case .games:        return "Add the games you keep opening. Website categories are optional."
        case .shopping:     return "Add the shopping apps you keep opening. Website categories are optional."
        case .news:         return "Add the news and feed apps you keep opening. Website categories are optional."
        case .custom:       return "Add the apps you keep reaching for. Website categories are optional."
        case .adultContent: return "Adult sites are on. Add apps, or gambling sites too, if you want."
        case .gambling:     return "Pick one or both. Pawl handles the websites."
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
            switch keyStore.state() {
            case .unavailable:
                message = "Pawl can't read its saved key right now. Unlock your phone and try again."
                return
            case .paired:
                // 2.1: onboarding never replaces a paired key. Changing keys is the gated
                // re-pair in Unlock, so running setup again can't swap in a key within reach.
                keyPaired = true
                message = "Your key is already paired, so it stays your key. You can change it later from Unlock, after the wait."
                return
            case .unpaired:
                // 2.1: a phone that was already protecting (for example a new phone where the
                // key didn't transfer) gets no free pairing here. It goes through Unlock and waits.
                if model.setupWasAlreadyProtecting {
                    message = "Pawl was already protecting you, so a new key goes through the Unlock tab and becomes active after your cooling-off wait. Tap \u{201C}I don't have a key yet\u{201D} to finish setup."
                    return
                }
            }
            let newKey = try await security.pairNewKey(displayName: "Pawl key")
            guard keyStore.save(newKey) else {
                message = "Couldn't save the key. Try again."
                return
            }
            keyStore.clearPending()
            keyPaired = true
        } catch {
            message = error.localizedDescription
        }
    }
}

#Preview {
    OnboardingView(model: AppModel())
}
