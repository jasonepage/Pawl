// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  PawlMascot.swift
//  Pawl, Theme (2.3)
//
//  The Stooped Key: an old key with a bent back, two eyes and a mustache. He sits at the top of
//  the Unlock screen and his pose follows the unlock state. Tap him and he does a short dance.
//  The dance is only decoration: no sound, no haptics, and it never touches unlock logic.
//  With Reduce Motion on, the dance becomes a small nod.
//

import SwiftUI

struct PawlMascot: View {
    enum Pose: Equatable {
        case locked     // standing guard, apps blocked
        case waiting    // eyes closed, hourglass, the wait is running
        case open       // upright, looking away, apps open for now
        case noKey      // dashed outline, no key paired yet

        var assetName: String {
            switch self {
            case .locked: return "MascotLocked"
            case .waiting: return "MascotWaiting"
            case .open: return "MascotOpen"
            case .noKey: return "MascotNoKey"
            }
        }
    }

    /// Which pose goes with an unlock state. Pure, so it can be tested.
    static func pose(for state: UnlockState, isPaired: Bool) -> Pose {
        switch state {
        case .locked, .reading: return isPaired ? .locked : .noKey
        case .coolingOff: return .waiting
        case .unshielded: return .open
        }
    }

    let pose: Pose
    var size: CGFloat = 104

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var taps = 0

    private struct Dance {
        var angle: Double = 0
        var lift: CGFloat = 0
        var stretch: CGFloat = 1
    }

    var body: some View {
        // Reduce Motion: one small nod and nothing else.
        let angles: [Double] = reduceMotion ? [-6, 0, 0, 0, 0, 0] : [-12, 12, -10, 10, -4, 0]
        let lifts: [CGFloat] = reduceMotion ? [0, 0, 0, 0, 0] : [-18, 0, -12, 0, 0]
        let stretches: [CGFloat] = reduceMotion ? [1, 1, 1, 1, 1] : [1.04, 0.92, 1.03, 0.95, 1]

        Image(pose.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .contentShape(Rectangle())
            .keyframeAnimator(initialValue: Dance(), trigger: taps) { content, dance in
                content
                    .scaleEffect(x: 2 - dance.stretch, y: dance.stretch, anchor: .bottom)
                    .rotationEffect(.degrees(dance.angle), anchor: .bottom)
                    .offset(y: dance.lift)
            } keyframes: { _ in
                KeyframeTrack(\.angle) {
                    CubicKeyframe(angles[0], duration: 0.16)
                    CubicKeyframe(angles[1], duration: 0.18)
                    CubicKeyframe(angles[2], duration: 0.18)
                    CubicKeyframe(angles[3], duration: 0.18)
                    CubicKeyframe(angles[4], duration: 0.16)
                    CubicKeyframe(angles[5], duration: 0.20)
                }
                KeyframeTrack(\.lift) {
                    CubicKeyframe(lifts[0], duration: 0.20)
                    CubicKeyframe(lifts[1], duration: 0.18)
                    CubicKeyframe(lifts[2], duration: 0.18)
                    CubicKeyframe(lifts[3], duration: 0.18)
                    CubicKeyframe(lifts[4], duration: 0.30)
                }
                KeyframeTrack(\.stretch) {
                    CubicKeyframe(stretches[0], duration: 0.20)
                    CubicKeyframe(stretches[1], duration: 0.16)
                    CubicKeyframe(stretches[2], duration: 0.18)
                    CubicKeyframe(stretches[3], duration: 0.18)
                    CubicKeyframe(stretches[4], duration: 0.30)
                }
            }
            .onTapGesture { taps += 1 }
            .accessibilityHidden(true)   // decoration; the hero title says the state
    }
}

#Preview {
    HStack(spacing: 16) {
        PawlMascot(pose: .locked)
        PawlMascot(pose: .waiting)
        PawlMascot(pose: .open)
        PawlMascot(pose: .noKey)
    }
    .padding()
}
