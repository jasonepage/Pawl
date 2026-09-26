// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  Feedback.swift
//  Pawl — sound & haptics
//
//  Semantic, recovery-aware feedback. The reinforcement is ASYMMETRIC by design:
//  reward PROTECTION (relock, resisting an urge, a recognized key) and stay quiet/
//  understated on UNBLOCKING — we never want lifting the shield to feel rewarding.
//  Relapse logging gets NO feedback here on purpose (handled with calm copy in the UI).
//
//  iOS respects the system "System Haptics" switch automatically; we add an in-app
//  toggle (Settings) for users who open Pawl in public. All calls are cheap no-ops when
//  disabled. The literal auto-relock happens in the PawlMonitor background extension
//  (no UIKit there), so `relock()` is played when the APP observes protection re-engage
//  (the `.reapplyShield` effect / foreground sync) — the honest surrogate.
//

import UIKit
import AudioToolbox

@MainActor
enum Feedback {
    /// Shared with SettingsView's `@AppStorage` (UserDefaults.standard). Default on.
    static let enabledKey = "pawl.feedback.enabled"
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    // MARK: Protection (rewarded)

    /// The signature moment — the pawl catching the ratchet. Protection re-engaged.
    static func relock() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        AudioServicesPlaySystemSound(1104)   // short mechanical "tock"
    }

    /// A valid key was recognized — confirm the physical action landed.
    static func keyRecognized() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Resisting an urge / a clean-day milestone — warm, affirming.
    static func milestone() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: Unblocking (deliberately understated)

    /// Access granted. One soft tick — NOT a celebration.
    static func shieldLifted() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // MARK: Gentle warnings

    /// Wrong key, denial, or a soft "no" — a light nudge, never harsh/punishing.
    static func warning() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    // MARK: Breathing pacer (urge flow)

    static func breatheInhale() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
    }

    static func breatheExhale() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.3)
    }
}
