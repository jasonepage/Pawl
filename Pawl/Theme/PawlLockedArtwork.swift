// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  PawlLockedArtwork.swift
//  Pawl — paired-and-locked illustration
//
//  The painted asset stays completely still so the physical security key remains
//  the visual anchor. A small, infrequent SwiftUI "z" loop adds life without turning
//  the artwork into a tappable pet. Reduce Motion receives the unanimated painting.
//

import SwiftUI

struct PawlLockedArtwork: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var zOpacity = 0.0
    @State private var zTravel: CGFloat = 0

    var body: some View {
        Image("PawlUnlockLocked")
            .resizable()
            .scaledToFit()
            .overlay(alignment: .topTrailing) {
                if !reduceMotion {
                    sleepMarks
                        .padding(.top, 7)
                        .padding(.trailing, 23)
                }
            }
            .frame(maxWidth: 250, maxHeight: 150)
            .task(id: reduceMotion) { await runSleepLoop() }
            .accessibilityHidden(true)
    }

    private var sleepMarks: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text("z")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .offset(y: 8)
            Text("z")
                .font(.system(size: 23, weight: .bold, design: .rounded))
        }
        .foregroundStyle(PawlColor.hardwareText.opacity(0.88))
        .shadow(color: PawlColor.hardwareBg.opacity(0.45), radius: 2, y: 1)
        .opacity(zOpacity)
        .offset(x: zTravel * 9, y: zTravel * -24)
        .rotationEffect(.degrees(Double(zTravel) * 4))
    }

    @MainActor
    private func runSleepLoop() async {
        zOpacity = 0
        zTravel = 0
        guard !reduceMotion else { return }

        do {
            while !Task.isCancelled {
                // The pause is longer than the gesture so the card feels mostly still.
                try await Task.sleep(for: .seconds(1.4))
                zTravel = 0
                zOpacity = 0

                withAnimation(.easeIn(duration: 0.28)) {
                    zOpacity = 0.88
                }
                try await Task.sleep(for: .seconds(0.28))

                withAnimation(.easeOut(duration: 2.1)) {
                    zTravel = 1
                    zOpacity = 0
                }
                try await Task.sleep(for: .seconds(5.1))
            }
        } catch {
            // Leaving the screen or changing Reduce Motion cancels the decorative loop.
        }
    }
}

#Preview {
    PawlLockedArtwork()
        .padding(28)
        .background(PawlColor.hardwareBg)
}
