// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  UnlockView.swift
//  Pawl — the unlock screen
//
//  Deliberately dead-simple and large-type for the moment of urge and for older users:
//  one big status hero, one big primary action, short readable copy. All the real logic
//  (key assertion, cooling-off, grace, gated re-pair) lives unchanged in
//  UnlockViewModel — this file is only the presentation (SDS §4.2, §4.3).
//

import SwiftUI
import FamilyControls

struct UnlockView: View {
    @State private var vm: UnlockViewModel
    /// Screen Time access is off, so nothing is actually blocked no matter what the lock
    /// state says. The hero must say that instead of "Apps are blocked".
    var screenTimeOff: Bool = false

    /// 2.4: the timing card opens the Unlock timing editor, which needs the app model. nil in
    /// the developer setup flow, where the card is simply not shown.
    var model: AppModel? = nil

    init(shield: ShieldService,
         selection: FamilyActivitySelection,
         screenTimeOff: Bool = false,
         model: AppModel? = nil,
         commitmentProvider: @escaping () -> Commitment? = { nil }) {
        self.screenTimeOff = screenTimeOff
        self.model = model
        _vm = State(wrappedValue: UnlockViewModel(
            shield: shield,
            selection: selection,
            commitmentProvider: commitmentProvider
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    statusHero
                    if isLocked, vm.isPaired, !showScreenTimeOff, let model {
                        timingCard(model)
                    }
                    actionArea
                    if case .coolingOff = vm.state {
                        BlockedStrip(title: "Opening when the wait ends", selection: SharedState.loadSelection())
                    } else if case .unshielded = vm.state {
                        BlockedStrip(title: "Open right now", selection: SharedState.loadSelection())
                    } else if isLocked, !showScreenTimeOff {
                        BlockedStrip(title: "Blocked right now", selection: SharedState.loadSelection())
                    }
                    if let message = vm.message {
                        Text(message)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    footerArea
                    #if DEBUG
                    devControls
                    #endif
                }
                .padding(20)
            }
            .background(PawlColor.groupedBg)
            .toolbar(.hidden, for: .navigationBar)
            .task { vm.syncFromShared(); await vm.checkAllyDecision() }
        }
        .tint(PawlColor.brand)
    }

    // MARK: - Status hero (big, color-coded by state)

    private var statusHero: some View {
        VStack(spacing: 10) {
            statusArtwork
            Text(heroTitle)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(heroFg)
                .multilineTextAlignment(.center)
            if let endsAt = vm.phaseEndsAt {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(countdown(to: endsAt))
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(heroFg)
                }
                if let cap = heroCaption {
                    Text(cap)
                        .font(.title3)
                        .foregroundStyle(heroFg)
                }
            } else if vm.isOpenUntilLocked {
                Text("They stay open until you tap Lock now.")   // 2.4: no timer to show
                    .font(.title3)
                    .foregroundStyle(heroFg)
                    .multilineTextAlignment(.center)
            } else if showScreenTimeOff {
                Text("Pawl can't block anything until it's turned back on in Settings.")
                    .font(.body)
                    .foregroundStyle(heroFg)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, usesIllustration ? 28 : 40)
        .padding(.horizontal, 20)
        .background(heroBg)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// Every illustration is state-specific: hardware art for key states and phone/contact
    /// art for the ally handoff. The visuals never change the unlock state machine.
    @ViewBuilder
    private var statusArtwork: some View {
        if showScreenTimeOff {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50, weight: .semibold))
                .foregroundStyle(heroFg)
        } else if isReading {
            PawlReadingArtwork()
        } else if usesNoKeyArtwork {
            Image("PawlUnlockNoKey")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 210, maxHeight: 130)
                .accessibilityHidden(true)
        } else if usesLockedArtwork {
            PawlLockedArtwork()
        } else if isAwaitingAlly {
            PawlAllyArtwork()
        } else if isUnshielded {
            PawlOpenArtwork()
        } else {
            PawlStateGlyph(symbol: stateSymbol, color: heroFg)
        }
    }

    // MARK: - Timing card (2.4)

    /// The wait and the open time, side by side, in the space under the hero. Tap it to change
    /// them (the same editor as Settings, with the same rule: stricter applies now, looser
    /// waits out your current wait).
    private func timingCard(_ model: AppModel) -> some View {
        NavigationLink {
            FrictionView(model: model)
        } label: {
            HStack(spacing: 0) {
                timingStat(DurationText.wait(seconds: model.cooldownSeconds), "wait")
                Rectangle().fill(Color.primary.opacity(0.1)).frame(width: 1).padding(.vertical, 10)
                timingStat(DurationText.open(seconds: model.graceSeconds), "open")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(PawlColor.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(12)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(DurationText.summary(waitSeconds: model.cooldownSeconds, openSeconds: model.graceSeconds) + ". Tap to change.")
    }

    private func timingStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(value.count > 8 ? .title3 : .largeTitle, design: .rounded).weight(.bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(.primary)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }

    // MARK: - Primary action (one clear thing to do, per state)

    @ViewBuilder
    private var actionArea: some View {
        switch vm.state {
        case .locked:
            if vm.isPaired {
                bigButton("Tap to unlock", "key.fill",
                          bg: PawlColor.cleanBg, fg: PawlColor.cleanText) {
                    Task { await vm.beginUnlock() }
                }
                .disabled(vm.isBusy)
                // 2.4: with an ally and Pro, a second way to start the same wait (docs/18, D1).
                if let model, model.canAskAlly, let name = vm.allyName {
                    bigButton("Ask \(name)", "person.2.fill",
                              bg: PawlColor.cardBg, fg: .primary) { vm.askAlly() }
                    .disabled(vm.isBusy)
                }
                helper(vm.unlockHelpText)   // 2.4: follows the saved wait and open time
            } else if let model, model.canAskAlly, let name = vm.allyName {
                // 2.4: no key, but an ally. Their yes is the way to unlock.
                bigButton("Ask \(name)", "person.2.fill",
                          bg: PawlColor.cleanBg, fg: PawlColor.cleanText) { vm.askAlly() }
                .disabled(vm.isBusy)
                helper("\(name) decides. Their yes starts \(vm.unlockHelpShort).")
                Button("Pair a security key instead") { Task { await vm.pairKey() } }
                    .font(.subheadline.weight(.medium))
                    .disabled(vm.isBusy)
            } else {
                bigButton("Pair your security key", "key.fill",
                          bg: PawlColor.cleanBg, fg: PawlColor.cleanText) {
                    Task { await vm.pairKey() }
                }
                .disabled(vm.isBusy)
                helper("You'll need your security key to unlock. Pair it once to get started.")
            }

        case .reading:
            helper("Hold your security key to the phone…")

        case .awaitingAlly:
            // 2.4: a request is open with the ally. Apps stay blocked until a yes checks out.
            helper("\(vm.allyName ?? "Your ally") has been asked. Apps stay blocked until they say yes. Their yes starts the same wait your key starts.")
            bigButton("Use my key instead", "key.fill",
                      bg: PawlColor.cleanBg, fg: PawlColor.cleanText) {
                Task { await vm.beginUnlock() }
            }
            .disabled(vm.isBusy)
            bigButton("Cancel: keep apps locked", "lock.fill",
                      bg: PawlColor.cardBg, fg: .primary) { vm.cancel() }

        case .coolingOff:
            helper("Apps unlock when the timer reaches zero. Waiting it out is the whole point.")
            bigButton("Cancel: keep apps locked", "lock.fill",
                      bg: PawlColor.cardBg, fg: .primary) { vm.cancel() }

        case .unshielded:
            // 2.4: Lock now ends the open time early. With "Until I lock it" it's the only way.
            if vm.isOpenUntilLocked {
                helper("Apps stay open until you lock them. Nothing locks them for you.")
            } else {
                helper("Apps re-lock by themselves when the timer ends. You can also lock them now.")
            }
            bigButton("Lock now", "lock.fill",
                      bg: PawlColor.cleanBg, fg: PawlColor.cleanText) { vm.lockNow() }
        }
    }

    // MARK: - Footer (re-pair, kept small and out of the way)

    @ViewBuilder
    private var footerArea: some View {
        if let endsAt = vm.pendingKeyEndsAt {
            VStack(spacing: 10) {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text("New key becomes active in \(countdown(to: endsAt))")
                        .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                Button("Cancel key change", role: .cancel) { vm.cancelKeyChange() }
                    .font(.callout)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        } else if isLocked && vm.isPaired {
            Button("Re-pair security key") { Task { await vm.pairKey() } }
                .font(.body)
                .foregroundStyle(PawlColor.brand)
                .disabled(vm.isBusy)
                .padding(.top, 4)
        }
    }

    #if DEBUG
    @ViewBuilder
    private var devControls: some View {
        VStack(spacing: 6) {
            switch vm.state {
            case .coolingOff, .unshielded:
                Button("Dev: skip the wait") { vm.devSkipWait() }
            default:
                EmptyView()
            }
            if vm.pendingKeyEndsAt != nil {
                Button("Dev: finish re-pair now") { vm.devSkipKeyWait() }
            }
            if vm.pairedCredential != nil {
                Button("Dev: remove paired key") { vm.devClearKey() }
            }
        }
        .font(.footnote)
        .foregroundStyle(.orange)
        .padding(.top, 8)
    }
    #endif

    // MARK: - Small building blocks

    private func bigButton(_ title: String, _ symbol: String,
                           bg: Color, fg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
        }
        .buttonStyle(PawlBigButtonStyle(background: bg, foreground: fg))
    }

    private func helper(_ text: String) -> some View {
        Text(text)
            .font(.title3)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - State → appearance

    private var isLocked: Bool {
        if case .locked = vm.state { return true }
        return false
    }

    private var isReading: Bool {
        if case .reading = vm.state { return true }
        return false
    }

    private var isUnshielded: Bool {
        if case .unshielded = vm.state { return true }
        return false
    }

    private var isAwaitingAlly: Bool {
        if case .awaitingAlly = vm.state { return true }
        return false
    }

    /// The painting shows Pawl guarding a paired physical key, so it would be misleading
    /// in the no-key state or while Screen Time protection is unavailable.
    private var usesLockedArtwork: Bool {
        isLocked && vm.isPaired && !showScreenTimeOff
    }

    /// Setup and registration show the real product category instead of the retired
    /// antique cat-key silhouette. The art contains no state or action of its own.
    private var usesNoKeyArtwork: Bool {
        guard !vm.isPaired && !showScreenTimeOff else { return false }
        switch vm.state {
        case .locked, .reading: return true
        case .awaitingAlly, .coolingOff, .unshielded: return false
        }
    }

    private var usesIllustration: Bool {
        guard !showScreenTimeOff else { return false }
        if usesLockedArtwork || usesNoKeyArtwork { return true }
        switch vm.state {
        case .reading, .awaitingAlly, .unshielded: return true
        case .locked, .coolingOff: return false
        }
    }

    /// Only the locked state claims apps are blocked, so that is the only state to correct.
    private var showScreenTimeOff: Bool { screenTimeOff && isLocked }

    /// One symbol per state for the states without painted art.
    private var stateSymbol: String {
        switch vm.state {
        case .locked: return (vm.isPaired || vm.hasAlly) ? "lock.fill" : "key.fill"
        case .reading: return "key.radiowaves.forward.fill"
        case .awaitingAlly: return "person.2.fill"
        case .coolingOff: return "hourglass"
        case .unshielded: return "lock.open.fill"
        }
    }

    private var heroBg: Color {
        if showScreenTimeOff { return PawlColor.dangerText.opacity(0.15) }
        switch vm.state {
        case .locked: return vm.isPaired ? PawlColor.hardwareBg : PawlColor.cardBg
        case .reading, .awaitingAlly: return PawlColor.cardBg
        case .coolingOff, .unshielded: return PawlColor.urgeBg
        }
    }

    private var heroFg: Color {
        if showScreenTimeOff { return PawlColor.dangerText }
        switch vm.state {
        case .locked: return vm.isPaired ? PawlColor.hardwareText : .primary
        case .reading, .awaitingAlly: return .primary
        case .coolingOff, .unshielded: return PawlColor.urgeText
        }
    }

    private var heroTitle: String {
        if showScreenTimeOff { return "Screen Time is off" }
        switch vm.state {
        case .locked: return (vm.isPaired || vm.hasAlly) ? "Apps are blocked" : "Set up your key"
        case .reading: return "Checking your key"
        case .awaitingAlly: return "Asking \(vm.allyName ?? "your ally")"      // 2.4
        case .coolingOff: return "Unlocking soon"
        case .unshielded: return "Apps unlocked"
        }
    }

    private var heroCaption: String? {
        switch vm.state {
        case .coolingOff: return "until apps unlock"
        case .unshielded: return "until apps re-lock"
        case .awaitingAlly: return "until the request expires"   // 2.4
        default: return nil
        }
    }

    private func countdown(to endsAt: Date) -> String {
        let remaining = max(0, Int(endsAt.timeIntervalSinceNow))
        // 2.4: custom times can run for hours, so show h:mm:ss past an hour.
        if remaining >= 3600 {
            return String(format: "%d:%02d:%02d", remaining / 3600, (remaining % 3600) / 60, remaining % 60)
        }
        return String(format: "%d:%02d", remaining / 60, remaining % 60)
    }
}


// MARK: - Blocked apps strip (2.4)

/// The blocked apps, categories and sites as a row of icons and names. SwiftUI draws each one
/// from its Screen Time token, so the person sees "Instagram" with its icon while Pawl itself
/// still never learns the name. Shown during the wait and the open time.
struct BlockedStrip: View {
    let title: String
    let selection: FamilyActivitySelection
    @State private var expanded = false

    private var isEmpty: Bool {
        selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty && selection.webDomainTokens.isEmpty
    }

    var body: some View {
        if !isEmpty {
            PawlCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    BlockedIconRow(selection: selection, sites: nil)
                }
            }
            .accessibilityElement(children: .contain)
        }
    }
}

/// One scrolling row: app icons, category icons, then site names as pills.
struct BlockedIconRow: View {
    let selection: FamilyActivitySelection
    /// Typed sites to show as pills after the tokens. nil shows only the picker's web domains.
    let sites: [String]?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(Array(selection.applicationTokens), id: \.self) { token in
                    Label(token)
                        .labelStyle(.iconOnly)
                        .font(.system(size: 40))
                        .frame(width: 44, height: 44)
                }
                ForEach(Array(selection.categoryTokens), id: \.self) { token in
                    Label(token)
                        .labelStyle(.iconOnly)
                        .font(.system(size: 40))
                        .frame(width: 44, height: 44)
                }
                ForEach(Array(selection.webDomainTokens), id: \.self) { token in
                    Label(token)
                        .labelStyle(.titleOnly)
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(PawlColor.groupedBg)
                        .clipShape(Capsule())
                }
                ForEach(sites ?? [], id: \.self) { site in
                    Text(site)
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(PawlColor.groupedBg)
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 2)
        }
    }
}
