// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  UnlockView.swift
//  Pawl — the unlock screen
//
//  Deliberately dead-simple and large-type for the moment of urge and for older users:
//  one big status hero, one big primary action, short readable copy. All the real logic
//  (key assertion, cooling-off, grace, sponsor approval, gated re-pair) lives unchanged in
//  UnlockViewModel — this file is only the presentation (SDS §4.2, §4.3).
//

import SwiftUI
import FamilyControls

struct UnlockView: View {
    @State private var vm: UnlockViewModel

    init(shield: ShieldService,
         selection: FamilyActivitySelection,
         commitmentProvider: @escaping () -> Commitment? = { nil },
         sponsorModeProvider: @escaping () -> Bool = { false },
         approval: UnlockApprovalService? = nil) {
        _vm = State(wrappedValue: UnlockViewModel(
            shield: shield,
            selection: selection,
            commitmentProvider: commitmentProvider,
            sponsorModeProvider: sponsorModeProvider,
            approval: approval
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    statusHero
                    actionArea
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
            .task { vm.syncFromShared() }
        }
        .tint(PawlColor.brand)
    }

    // MARK: - Status hero (big, color-coded by state)

    private var statusHero: some View {
        VStack(spacing: 10) {
            Image(systemName: heroIcon)
                .font(.system(size: 50, weight: .semibold))
                .foregroundStyle(heroFg)
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
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(heroBg)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .combine)
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
                helper("Using your key starts a 15-minute wait. Apps stay locked until it's over, then re-lock on their own.")
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

        case .awaitingApproval:
            helper("Your sponsor needs to say yes. The wait starts only once they approve.")
            bigButton("Cancel — keep apps locked", "lock.fill",
                      bg: PawlColor.cardBg, fg: .primary) { vm.cancel() }

        case .coolingOff:
            helper("Apps unlock when the timer reaches zero. Waiting it out is the whole point.")
            bigButton("Cancel — keep apps locked", "lock.fill",
                      bg: PawlColor.cardBg, fg: .primary) { vm.cancel() }

        case .unshielded:
            helper("Apps re-lock by themselves when the timer ends. There's nothing you need to do.")
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
            case .awaitingApproval:
                Button("Dev: simulate sponsor approve") { vm.devSimulateSponsor(approved: true) }
                Button("Dev: simulate sponsor deny") { vm.devSimulateSponsor(approved: false) }
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

    private var heroBg: Color {
        switch vm.state {
        case .locked: return vm.isPaired ? PawlColor.cleanBg : PawlColor.cardBg
        case .reading: return PawlColor.cardBg
        case .awaitingApproval, .coolingOff, .unshielded: return PawlColor.urgeBg
        }
    }

    private var heroFg: Color {
        switch vm.state {
        case .locked: return vm.isPaired ? PawlColor.cleanText : .primary
        case .reading: return .primary
        case .awaitingApproval, .coolingOff, .unshielded: return PawlColor.urgeText
        }
    }

    private var heroIcon: String {
        switch vm.state {
        case .locked: return vm.isPaired ? "lock.fill" : "key"
        case .reading: return "key.fill"
        case .awaitingApproval: return "person.2.fill"
        case .coolingOff: return "hourglass"
        case .unshielded: return "lock.open.fill"
        }
    }

    private var heroTitle: String {
        switch vm.state {
        case .locked: return vm.isPaired ? "Apps are blocked" : "Set up your key"
        case .reading: return "Checking your key"
        case .awaitingApproval: return "Waiting for sponsor"
        case .coolingOff: return "Unlocking soon"
        case .unshielded: return "Apps unlocked"
        }
    }

    private var heroCaption: String? {
        switch vm.state {
        case .coolingOff: return "until apps unlock"
        case .unshielded: return "until apps re-lock"
        default: return nil
        }
    }

    private func countdown(to endsAt: Date) -> String {
        let remaining = max(0, Int(endsAt.timeIntervalSinceNow))
        return String(format: "%d:%02d", remaining / 60, remaining % 60)
    }
}
