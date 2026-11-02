// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  OnboardingView.swift
//  Pawl: first run (v2, docs/26 and docs/27)
//
//  Four screens, then the payoff. Explain first, then one permission, then choose what to
//  block (website chips that block at once, toggles, and Apple's picker only as the way to add
//  apps), then the unlock. Blocks turn on only once a key is paired or an ally has joined,
//  so Pawl never makes a lock with no exit. The hours question is a reward after the block,
//  not homework before it.
//

import SwiftUI
import FamilyControls
import CloudKit

struct OnboardingView: View {
    let model: AppModel

    @State private var step = 0                  // 0 welcome, 1 permission, 2 choose, 3 unlock, 4 done
    @State private var selection = FamilyActivitySelection()
    @State private var blockGambling = false
    @State private var blockAdult = false
    @State private var isPickerPresented = false
    @State private var siteEntry = ""
    @State private var moreSites = false

    enum UnlockChoice { case key, ally }
    @State private var unlockChoice: UnlockChoice? = nil
    @State private var keyPaired = false
    @State private var working = false
    @State private var message: String?

    // Ally during setup
    @State private var invite: AllyInvite?
    @State private var allyJoined: AllyPairing?
    @State private var showPaywall = false

    // Payoff
    @State private var hoursPerDay: Double = 0

    private let security = SecurityKeyService()
    private let keyStore = KeyStore()

    var body: some View {
        VStack(spacing: 0) {
            if (1...3).contains(step) {
                PawlStepDots(current: step - 1, total: 3)
                    .padding(.top, 14)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    content
                }
                .padding(20)
            }
            VStack(spacing: 10) {
                if let message {
                    Label(message, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                        .background(PawlColor.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                footer
            }
            .padding(20)
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        .background(PawlColor.groupedBg)
        .tint(PawlColor.brand)
        .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
        .sheet(isPresented: $showPaywall, onDismiss: { Task { await model.pro.refreshEntitlements() } }) {
            PaywallView(pro: model.pro)
        }
        .onChange(of: step) { _, _ in message = nil }
        .onChange(of: model.auth.isApproved) { _, ok in if ok, step == 1 { step = 2 } }
        .task { await model.noteSetupStarted() }
    }

    // MARK: Screens

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: welcome
        case 1: permission
        case 2: choose
        case 3: unlock
        default: payoff
        }
    }

    private var welcome: some View {
        VStack(spacing: 18) {
            painting("PawlOnboarding-welcome", height: 190)
                .padding(.top, 12)
            heading("Pawl locks apps until you tap a small key.", "")
            body("Pick the apps and sites. Pawl blocks them with Apple's Screen Time. To open one again you tap a security key you keep somewhere else, then wait 15 minutes.")
            card {
                VStack(alignment: .leading, spacing: 10) {
                    infoRow("key.fill", "The key is about $30", "Any USB-C security key works. You buy it once.")
                    infoRow("person.2.fill", "Or an ally, with Pawl Pro", "Someone you trust says yes from their phone instead.")
                    infoRow("hand.raised.fill", "No account, nothing collected", "Your choices stay on this iPhone.")
                }
            }
        }
    }

    private var permission: some View {
        VStack(spacing: 18) {
            painting("PawlOnboarding-screentime")
            heading("One permission", "Pawl needs Screen Time to do the blocking.")
            body("It never sees which apps you pick. Your choices stay on this iPhone.")
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
                Text(err).font(.footnote).foregroundStyle(PawlColor.dangerText)
            }
        }
    }

    private static let popularSites = ["tiktok.com", "instagram.com", "x.com", "youtube.com", "reddit.com", "facebook.com", "snapchat.com"]
    private static let gamblingSites = ["draftkings.com", "fanduel.com", "kalshi.com", "polymarket.com"]
    private static let moreSiteGroups: [(String, [String])] = [
        ("Games", ["roblox.com", "twitch.tv", "chess.com", "poki.com"]),
        ("Shopping", ["amazon.com", "temu.com", "shein.com", "ebay.com"]),
        ("News", ["news.google.com", "cnn.com", "foxnews.com", "nytimes.com"]),
    ]

    private var choose: some View {
        VStack(alignment: .leading, spacing: 16) {
            painting("PawlOnboarding-choose", height: 120)
            heading("What should Pawl block?", "Tap a site to block it right now.")

            chipGroup("Social", Self.popularSites)

            card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apps").font(.headline)
                            Text(selection.applicationTokens.isEmpty
                                 ? "The TikTok app, the Instagram app, any app."
                                 : (selection.applicationTokens.count == 1 ? "1 app picked" : "\(selection.applicationTokens.count) apps picked"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Button(selection.applicationTokens.isEmpty ? "Add apps" : "Change") { isPickerPresented = true }
                            .buttonStyle(.borderedProminent)
                    }
                    Text("Apple's list shows every app on your phone. Search for the one you want, tap the circle next to it, then tap Done in the top right.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            categoryToggle(title: "Gambling sites",
                           subtitle: "Pawl's list of sportsbook and casino sites. Off unless you turn it on.",
                           isOn: $blockGambling,
                           locked: model.setupWasAlreadyProtecting && model.gamblingOn)
            if blockGambling { chipGroup("Also block", Self.gamblingSites) }
            categoryToggle(title: "Adult sites",
                           subtitle: "Apple's adult website filter. Off unless you turn it on.",
                           isOn: $blockAdult,
                           locked: model.setupWasAlreadyProtecting && model.adultOn)

            card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Any website").font(.headline)
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
                    Button(moreSites ? "Fewer suggestions" : "More sites: games, shopping, news") { withAnimation { moreSites.toggle() } }
                        .font(.footnote.weight(.medium))
                    if moreSites {
                        ForEach(Self.moreSiteGroups, id: \.0) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(group.0).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                SiteSuggestionChips(sites: group.1, alreadyAdded: model.customDomains) { model.addCustomDomains($0) }
                            }
                        }
                    }
                }
            }

            if !blockedLine.isEmpty {
                Text("Blocking: \(blockedLine)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PawlColor.cleanText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func chipGroup(_ title: String, _ sites: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            SiteSuggestionChips(sites: sites, alreadyAdded: model.customDomains) { site in
                model.addCustomDomains(site)
            }
            if let m = model.blockChangeMessage, title == "Social" {
                Text(m).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// The running summary: sites, categories, apps.
    private var blockedLine: String {
        var parts = model.customDomains
        if blockGambling { parts.append("Gambling sites") }
        if blockAdult { parts.append("Adult sites") }
        let n = selection.applicationTokens.count
        if n > 0 { parts.append(n == 1 ? "1 app" : "\(n) apps") }
        return parts.joined(separator: ", ")
    }

    private var unlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            painting("PawlOnboarding-unlock", height: 130)
            heading("Lock it with your key", "Or with an ally. One has to be ready before blocks turn on.")
            if !keyPaired && allyJoined == nil {
                HStack(spacing: 12) {
                    choiceCard("key.fill", "Security key", "Plug it in and touch it. About 3 taps.",
                               selected: unlockChoice == .key) { unlockChoice = .key }
                    choiceCard("person.2.fill", "Ally (Pro)", "They say yes from their phone. You send one link.",
                               selected: unlockChoice == .ally) { unlockChoice = .ally }
                }
            }
            if keyPaired {
                card {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Key paired", systemImage: "checkmark.circle.fill").font(.headline)
                        Text("Now put it somewhere that takes real effort to reach: a friend across town, a time lock box, your desk at work. More ideas in Settings.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else if let joined = allyJoined {
                card {
                    Label("\(joined.name) is your ally", systemImage: "person.fill.checkmark").font(.headline)
                }
            } else if unlockChoice == .key {
                body("Plug in your USB-C security key and tap Pair. When your iPhone asks, touch the key. To open a blocked app later you tap the key again, then wait 15 minutes.")
            } else if unlockChoice == .ally {
                VStack(alignment: .leading, spacing: 10) {
                    body("Send one link to someone you trust. When they open it, Pawl asks them to join. They cannot see which apps or sites you block. Needs iCloud on both phones and Pawl Pro for you only.")
                    if let invite {
                        ShareLink(item: invite, preview: SharePreview("Be my Pawl ally")) {
                            Label("Send the invite", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PawlBigButtonStyle(background: PawlColor.brand, foreground: .white))
                        Button("Check if they joined") { Task { await checkAllyJoined() } }
                            .disabled(working)
                    }
                }
            }
        }
    }

    private var payoff: some View {
        VStack(spacing: 18) {
            painting("PawlOnboarding-lockin", height: 170)
                .padding(.top, 12)
            heading("Blocks are on", blockedLine.isEmpty ? "" : "Blocking \(blockedLine).")
            body("Open one of them and watch it bounce. To get back in: \(keyPaired ? "tap your key" : "ask \(allyJoined?.name ?? "your ally")"), then wait 15 minutes.")
            card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("How many hours a day did this take?").font(.headline)
                    HStack {
                        Slider(value: $hoursPerDay, in: 0...8, step: 0.5)
                        Text(hoursPerDay == hoursPerDay.rounded() ? "\(Int(hoursPerDay)) h" : String(format: "%.1f h", hoursPerDay))
                            .font(.body.monospacedDigit())
                            .frame(width: 44, alignment: .trailing)
                    }
                    if hoursPerDay > 0 {
                        Text("That's about \(hoursPerDay == hoursPerDay.rounded() ? "\(Int(hoursPerDay))" : String(format: "%.1f", hoursPerDay)) hours a day back. Home will count it.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PawlColor.cleanText)
                    } else {
                        Text("Optional. Home uses it to show what you get back.")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
            Text("Turning off Screen Time for Pawl removes the blocks. For a firmer lock, someone you trust can set a Screen Time passcode. That is in Settings.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }

    // MARK: Footer

    private var nothingSelected: Bool {
        selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty
            && model.customDomains.isEmpty && !blockGambling && !blockAdult
    }
    private var unlockReady: Bool { keyPaired || allyJoined != nil }

    @ViewBuilder
    private var footer: some View {
        switch step {
        case 0:
            primary("Block my first app") { step = model.auth.isApproved ? 2 : 1 }
        case 1:
            if model.auth.isApproved {
                primary("Continue") { step = 2 }
            } else {
                primary("Allow Screen Time") { Task { await model.auth.requestAuthorization() } }
            }
        case 2:
            VStack(spacing: 6) {
                primary("Continue") { step = 3 }
                    .disabled(nothingSelected)
                    .opacity(nothingSelected ? 0.5 : 1)
                if nothingSelected {
                    Text("Tap a site or add an app to continue.").font(.caption).foregroundStyle(.secondary)
                }
            }
        case 3:
            VStack(spacing: 10) {
                if !unlockReady {
                    if unlockChoice == .key {
                        secondary(working ? "Waiting for your key\u{2026}" : "Pair security key") { Task { await pairKey() } }
                            .disabled(working)
                    } else if unlockChoice == .ally, invite == nil {
                        secondary(working ? "One moment\u{2026}" : "Invite my ally") { Task { await makeInvite() } }
                            .disabled(working)
                    }
                }
                primary(working ? "Turning on blocks\u{2026}" : "Turn on blocks") { Task { await turnOn() } }
                    .disabled(!unlockReady || working)
                    .opacity(unlockReady ? 1 : 0.5)
                if !unlockReady, unlockChoice != nil {
                    Text(unlockChoice == .key ? "Blocks turn on once your key is paired." : "Blocks turn on once your ally has joined.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        default:
            primary("Go to Home") {
                model.hoursPerDay = hoursPerDay
                model.setupPayoffPending = false
            }
        }
    }

    // MARK: Actions

    private func addTypedSite() {
        let text = siteEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if model.addCustomDomains(text) > 0 { siteEntry = "" }
    }

    private func turnOn() async {
        working = true
        model.setOnboardingWebCategories(gambling: blockGambling, adult: blockAdult)
        model.setupPayoffPending = true
        await model.activate(selection: selection, vertical: blockGambling ? .gambling : (blockAdult ? .adultContent : .custom))
        working = false
        step = 4
    }

    private func makeInvite() async {
        guard model.pro.isPro else { showPaywall = true; return }
        working = true
        defer { working = false }
        guard await AllyCloud.shared.isSignedIn() else {
            message = "Sign in to iCloud on this phone first (Settings, your name)."
            return
        }
        do {
            let share = try await AllyCloud.shared.share()
            invite = AllyInvite(share: share, container: AllyCloud.shared.container)
            message = nil
        } catch let e as CKError where e.code == .quotaExceeded {
            message = "Your iCloud storage is full, so Pawl can't save the invite there. Free up some iCloud space and try again, or use a key."
        } catch {
            message = "Couldn't make the invite. \(error.localizedDescription)"
        }
    }

    private func checkAllyJoined() async {
        working = true
        defer { working = false }
        do {
            let pairing = try await AllyCloud.shared.fetchAllyLink()
            await model.activateAllyDuringSetup(pairing)
            allyJoined = pairing
            message = nil
        } catch AllyCloudError.allyNotJoined {
            message = "Nobody has joined yet. Ask them to open the link."
        } catch AllyCloudError.allyIsOwner {
            message = "That link was opened on a phone signed in to your own Apple Account. An ally needs their own."
        } catch {
            message = "Couldn't check. \(error.localizedDescription)"
        }
    }

    // MARK: Pieces

    private func heading(_ title: String, _ sub: String) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.system(.largeTitle, design: .rounded).weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            if !sub.isEmpty {
                Text(sub).font(.title3).foregroundStyle(PawlColor.cleanText)
                    .fixedSize(horizontal: false, vertical: true)
            }
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

    /// 2.4: one painting per step (design/pawl-cat-v3/onboarding-art). The cat is supporting
    /// art; the key is the product. Transparent, so it sits on the page background.
    private func painting(_ name: String, height: CGFloat = 150) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: height)
            .padding(.top, 4)
            .accessibilityHidden(true)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        PawlCard(content: content)
    }

    /// A small icon, a title and one line of explanation.
    private func infoRow(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline).foregroundStyle(PawlColor.brand).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.caption).foregroundStyle(.secondary).lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    /// 2.4: one of the two unlock choices, as a tappable card.
    private func choiceCard(_ symbol: String, _ title: String, _ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(selected ? PawlColor.cleanText : PawlColor.brand)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(selected ? PawlColor.cleanText : .primary)
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(selected ? PawlColor.cleanText.opacity(0.85) : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .padding(14)
            .background(selected ? PawlColor.cleanBg : PawlColor.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? PawlColor.brand : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
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

    /// A filled, tappable category card with a toggle, matching the app's card style.
    /// `locked`: already on from before, so setup can't turn it off (that needs the key, in
    /// Settings). Shown on and disabled, with a line saying so.
    private func categoryToggle(title: String, subtitle: String, isOn: Binding<Bool>,
                                locked: Bool = false) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(locked ? "Already on. Turning it off needs your key, in Settings." : subtitle)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .disabled(locked)
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
                    message = "Pawl was already protecting you, so pair the key from the Unlock tab after setup. Your first key works right away; a replacement waits."
                    return
                }
            }
            // 2.3: say right away what to do, so the tap visibly did something.
            message = "Plug in your key now. When your iPhone asks, touch the key."
            let newKey = try await security.pairNewKey(displayName: "Pawl key")
            guard keyStore.save(newKey) else {
                message = "Couldn't save the key. Try again."
                return
            }
            keyStore.clearPending()
            message = nil
            keyPaired = true
        } catch {
            message = error.localizedDescription
        }
    }
}

#Preview {
    OnboardingView(model: AppModel())
}
