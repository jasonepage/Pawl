// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  PawlStateArtwork.swift
//  Pawl — restrained motion for painted state illustrations
//

import SwiftUI

/// The phone and security key stay still while a small signal repeats in the gap between
/// them. This explains the hardware check without making the illustration tappable.
struct PawlReadingArtwork: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var signalOut = false

    var body: some View {
        Image("PawlUnlockReading")
            .resizable()
            .scaledToFit()
            .overlay {
                if !reduceMotion {
                    signal
                        .offset(x: 4, y: 11)
                }
            }
            .frame(maxWidth: 225, maxHeight: 150)
            .task(id: reduceMotion) { await runSignalLoop() }
            .accessibilityHidden(true)
    }

    private var signal: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(PawlColor.hardwareText.opacity(0.72), lineWidth: 2)
                    .frame(width: CGFloat(18 + index * 13),
                           height: CGFloat(18 + index * 13))
                    .scaleEffect(signalOut ? 1.28 : 0.68)
                    .opacity(signalOut ? 0 : 0.72)
                    .animation(
                        signalOut
                            ? .easeOut(duration: 1.15).delay(Double(index) * 0.14)
                            : nil,
                        value: signalOut
                    )
            }
        }
    }

    @MainActor
    private func runSignalLoop() async {
        signalOut = false
        guard !reduceMotion else { return }

        do {
            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(0.35))
                signalOut = true
                try await Task.sleep(for: .seconds(1.75))
                signalOut = false
                try await Task.sleep(for: .seconds(0.12))
            }
        } catch {
            // Navigation and Reduce Motion changes cancel decorative motion.
        }
    }
}

/// The unlocked state is deliberately still most of the time. A rare natural blink is
/// enough character; the key remains visible and there is no touch response.
struct PawlOpenArtwork: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var eyesClosed = false

    var body: some View {
        ZStack {
            art("PawlUnlockOpen")
            art("PawlUnlockOpenBlink")
                .opacity(eyesClosed ? 1 : 0)
        }
        .frame(maxWidth: 220, maxHeight: 110)
        .task(id: reduceMotion) { await runBlinkLoop() }
        .accessibilityHidden(true)
    }

    private func art(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
    }

    @MainActor
    private func runBlinkLoop() async {
        eyesClosed = false
        guard !reduceMotion else { return }

        do {
            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(6.2))
                withAnimation(.linear(duration: 0.09)) { eyesClosed = true }
                try await Task.sleep(for: .seconds(0.16))
                withAnimation(.linear(duration: 0.11)) { eyesClosed = false }
            }
        } catch {
            // Navigation and Reduce Motion changes cancel decorative motion.
        }
    }
}

/// The ally path is a human handoff rather than a hardware interaction. Pawl waits on
/// the phone while a quiet pulse around the contact confirms that the request is active.
struct PawlAllyArtwork: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var eyesClosed = false
    @State private var pulseScale: CGFloat = 0.92
    @State private var pulseOpacity = 0.0

    var body: some View {
        ZStack {
            if !reduceMotion {
                Circle()
                    .stroke(PawlColor.brand, lineWidth: 2)
                    .frame(width: 43, height: 43)
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)
                    .position(x: 217, y: 54)
            }

            art("PawlUnlockAlly")
            art("PawlUnlockAllyBlink")
                .opacity(eyesClosed ? 1 : 0)
        }
        .frame(width: 250, height: 125)
        .task(id: reduceMotion) { await runPulseLoop() }
        .task(id: reduceMotion) { await runBlinkLoop() }
        .accessibilityHidden(true)
    }

    private func art(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
    }

    @MainActor
    private func runPulseLoop() async {
        pulseScale = 0.92
        pulseOpacity = 0
        guard !reduceMotion else { return }

        do {
            while !Task.isCancelled {
                pulseScale = 0.92
                pulseOpacity = 0.42
                withAnimation(.easeOut(duration: 1.35)) {
                    pulseScale = 1.55
                    pulseOpacity = 0
                }
                try await Task.sleep(for: .seconds(2.25))
            }
        } catch {
            // Leaving the screen or changing Reduce Motion cancels decorative motion.
        }
    }

    @MainActor
    private func runBlinkLoop() async {
        eyesClosed = false
        guard !reduceMotion else { return }

        do {
            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(6.8))
                withAnimation(.linear(duration: 0.09)) { eyesClosed = true }
                try await Task.sleep(for: .seconds(0.16))
                withAnimation(.linear(duration: 0.11)) { eyesClosed = false }
            }
        } catch {
            // Leaving the screen or changing Reduce Motion cancels decorative motion.
        }
    }
}

#Preview("State art") {
    VStack(spacing: 20) {
        PawlReadingArtwork()
        PawlOpenArtwork()
        PawlAllyArtwork()
    }
    .padding(28)
    .background(PawlColor.hardwareBg)
}
