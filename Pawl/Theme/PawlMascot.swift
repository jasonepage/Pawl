// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  PawlMascot.swift
//  Pawl, Theme (2.4)
//
//  Pawl: an old brass key with cat ears, heavy lids and a handlebar mustache. He is drawn here
//  in code (shapes from PawlMascotArt plus circles for the eyes) so his lids, a floating paw and
//  a few props can move. His pose follows the unlock state:
//
//    locked   asleep on the job, breathing, the door stays locked
//    waiting  half-lidded, blinks now and then, an hourglass flips beside him
//    open     hands the key over, a slow nod with his eyes closed
//    noKey    a dashed outline, no face: nothing is paired yet
//    resisted the swipe on a loop: a paw bats an app away (urge screen)
//    idle     half-lidded, a blink every few seconds (home)
//
//  Tap him and a paw floats in and bats an app off the table (the swipe). None of this touches
//  unlock logic. With Reduce Motion on, he only blinks and nothing floats.
//

import SwiftUI

struct PawlMascot: View {
    enum Pose: Equatable {
        case locked, waiting, open, noKey, resisted, idle
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
    /// A halo floats over him. Used for a streak milestone.
    var halo = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Eyes. lid 1 = half-lidded (his resting face), 0.5 = wide, 2.1 = shut.
    @State private var lidL: CGFloat = 1
    @State private var lidR: CGFloat = 1
    @State private var shutL = false
    @State private var shutR = false

    // The floating paw and the app tile it bats away.
    @State private var paw = PawState()
    @State private var tile = TileState()
    @State private var keyInPaw = false

    // Props and small body motion.
    @State private var breathe: CGFloat = 1
    @State private var sway: Double = 0
    @State private var hourglassTurns: Double = 0
    @State private var zPhase: CGFloat = 0     // 0 hidden ... 1 risen and faded
    @State private var haloLift: CGFloat = 0
    @State private var swiping = false

    private struct PawState: Equatable {
        var x: CGFloat = -80, y: CGFloat = 310, angle: Double = 0, opacity: Double = 0
    }
    private struct TileState: Equatable {
        var x: CGFloat = 600, y: CGFloat = 300, angle: Double = 0, opacity: Double = 0
    }

    // Palette, sampled from the reference drawing.
    private let gold  = PawlMascotArt.color(0xCB9F24)
    private let dark  = PawlMascotArt.color(0xAF8320)
    private let cream = PawlMascotArt.color(0xF0E0C0)
    private let ring  = PawlMascotArt.color(0x806010)
    private let lid   = PawlMascotArt.color(0xB18725)
    private let ink   = PawlMascotArt.color(0x1A1714)

    var body: some View {
        ZStack {
            if pose == .noKey {
                ghost
            } else {
                tileView
                keyBody
                    .scaleEffect(x: 1, y: breathe, anchor: .bottom)
                    .rotationEffect(.degrees(sway), anchor: .bottom)
                props
                pawView
            }
        }
        .frame(width: 512, height: 512)
        .scaleEffect(size / 512)
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .onTapGesture { tapped() }
        .task(id: pose) { await run() }
        .accessibilityHidden(true)   // decoration; the hero title says the state
    }

    // MARK: - Drawing

    private var keyBody: some View {
        ZStack {
            PolygonShape(polygons: PawlMascotArt.body).fill(gold)
            PolygonShape(polygons: PawlMascotArt.innerEars).fill(dark)
            PolygonShape(polygons: PawlMascotArt.stemDark).fill(dark)
            eye(cx: 210.1, scale: lidL, shut: shutL)
            eye(cx: 301.9, scale: lidR, shut: shutR)
            brows
            PolygonShape(polygons: PawlMascotArt.mustache).fill(cream)
        }
    }

    private var brows: some View {
        Path { p in
            p.move(to: CGPoint(x: 189.8, y: 140.4)); p.addLine(to: CGPoint(x: 237.7, y: 133.8))
            p.move(to: CGPoint(x: 274.3, y: 133.8)); p.addLine(to: CGPoint(x: 322.2, y: 140.4))
        }
        .stroke(cream, style: StrokeStyle(lineWidth: 9.8, lineCap: .round))
    }

    /// One eye: a cream disc, a pupil, a lid that slides down from the top, a brown ring, and a
    /// lash line that shows only when the lid is all the way down.
    private func eye(cx: CGFloat, scale: CGFloat, shut: Bool) -> some View {
        let cy: CGFloat = 185.6
        return ZStack {
            ZStack {
                Circle().fill(cream).frame(width: 58.6, height: 58.6)
                Circle().fill(ink).frame(width: 31.8, height: 31.8).offset(y: 0.4)
                VStack(spacing: 0) {
                    Rectangle().fill(lid).frame(height: 26.3)
                    Rectangle().fill(dark).frame(height: 3.4)
                }
                .frame(width: 60)
                .scaleEffect(x: 1, y: scale, anchor: .top)
                .padding(.top, 0.7)                                   // the lid's top edge, measured from the reference
                .frame(width: 60, height: 60, alignment: .top)
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            Circle().stroke(ring, lineWidth: 5.6).frame(width: 64.2, height: 64.2)
            Path { p in
                p.move(to: CGPoint(x: 12.1, y: 36.1))
                p.addQuadCurve(to: CGPoint(x: 52.1, y: 36.1), control: CGPoint(x: 32.1, y: 54.1))
            }
            .stroke(ring, style: StrokeStyle(lineWidth: 6, lineCap: .round))
            .frame(width: 64.2, height: 64.2)
            .opacity(shut ? 1 : 0)
        }
        .position(x: cx, y: cy)
    }

    private var ghost: some View {
        PolygonShape(polygons: PawlMascotArt.body)
            .stroke(gold, style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round, dash: [30, 20]))
    }

    private var pawView: some View {
        ZStack {
            Circle().fill(gold).frame(width: 72, height: 72)
            ForEach(0..<3, id: \.self) { i in
                let toe = [CGPoint(x: -22, y: -24), CGPoint(x: 0, y: -32), CGPoint(x: 22, y: -24)][i]
                Circle().fill(gold).frame(width: 28, height: 28).offset(x: toe.x, y: toe.y)
                Circle().fill(cream).frame(width: 12, height: 12).offset(x: toe.x, y: toe.y)
            }
            Ellipse().fill(cream).frame(width: 30, height: 24).offset(y: 6)
            if keyInPaw { securityKey.offset(x: -6, y: -6).rotationEffect(.degrees(-30)) }
        }
        .rotationEffect(.degrees(paw.angle))
        .position(x: paw.x, y: paw.y)
        .opacity(paw.opacity)
    }

    private var securityKey: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(PawlMascotArt.color(0x4C7F1C)).frame(width: 56, height: 28).offset(x: -12)
            RoundedRectangle(cornerRadius: 3).fill(PawlMascotArt.color(0xC9CED6)).frame(width: 22, height: 16).offset(x: 23)
            Circle().fill(gold).frame(width: 14, height: 14).offset(x: -18)
        }
    }

    private var tileView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14).fill(PawlMascotArt.color(0xD8DDE6)).frame(width: 60, height: 60)
            VStack(alignment: .leading, spacing: 4) {
                Capsule().fill(PawlMascotArt.color(0xB7C0CC)).frame(width: 32, height: 7)
                Capsule().fill(PawlMascotArt.color(0xB7C0CC)).frame(width: 24, height: 7)
            }
            .offset(x: -2, y: 2)
            Circle().fill(PawlMascotArt.color(0xD9534F)).frame(width: 18, height: 18).offset(x: 24, y: -24)
        }
        .rotationEffect(.degrees(tile.angle))
        .position(x: tile.x, y: tile.y)
        .opacity(tile.opacity)
    }

    @ViewBuilder
    private var props: some View {
        if pose == .locked {
            // The padlock: the door stays locked while he sleeps.
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 14, y: 42)); p.addLine(to: CGPoint(x: 14, y: 26))
                    p.addCurve(to: CGPoint(x: 54, y: 26), control1: CGPoint(x: 14, y: -1), control2: CGPoint(x: 54, y: -1))
                    p.addLine(to: CGPoint(x: 54, y: 42))
                }
                .stroke(ink, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                RoundedRectangle(cornerRadius: 12).fill(ink).frame(width: 68, height: 54).offset(y: 14)
                Circle().fill(gold).frame(width: 14, height: 14).offset(y: 15)
            }
            .frame(width: 68, height: 82)
            .position(x: 420, y: 426)
            // Two z's drifting up.
            Text("z").font(.system(size: 44, weight: .bold, design: .rounded)).foregroundStyle(ink)
                .position(x: 372 + 26 * zPhase, y: 110 - 70 * zPhase)
                .opacity(zPhase == 0 ? 0 : Double(1 - zPhase) * 0.9)
            Text("z").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(ink)
                .position(x: 396 + 26 * zPhase, y: 150 - 70 * zPhase)
                .opacity(zPhase == 0 ? 0 : Double(1 - zPhase) * 0.6)
        }
        if pose == .waiting {
            hourglass
                .rotationEffect(.degrees(hourglassTurns * 180))
                .position(x: 430, y: 120)
        }
        if halo {
            Ellipse().stroke(cream, lineWidth: 11).frame(width: 116, height: 26)
                .position(x: 256, y: 48 - haloLift)
        }
    }

    private var hourglass: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: 60, y: 0)); p.addLine(to: CGPoint(x: 60, y: 12))
                p.addLine(to: CGPoint(x: 36, y: 40)); p.addLine(to: CGPoint(x: 60, y: 68)); p.addLine(to: CGPoint(x: 60, y: 80))
                p.addLine(to: CGPoint(x: 0, y: 80)); p.addLine(to: CGPoint(x: 0, y: 68)); p.addLine(to: CGPoint(x: 24, y: 40))
                p.addLine(to: CGPoint(x: 0, y: 12)); p.closeSubpath()
            }
            .fill(gold)
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: 60, y: 0)); p.addLine(to: CGPoint(x: 60, y: 12))
                p.addLine(to: CGPoint(x: 36, y: 40)); p.addLine(to: CGPoint(x: 24, y: 40)); p.addLine(to: CGPoint(x: 0, y: 12)); p.closeSubpath()
            }
            .fill(ink.opacity(0.18))
        }
        .frame(width: 60, height: 80)
    }

    // MARK: - Motion

    /// Runs the loop for the current pose until the pose changes (the task is cancelled then).
    @MainActor private func run() async {
        // Reset to the resting face before each pose.
        withAnimation(.easeOut(duration: 0.2)) {
            lidL = 1; lidR = 1; shutL = false; shutR = false
            paw = PawState(); tile = TileState(); keyInPaw = false
            breathe = 1; sway = 0; zPhase = 0; haloLift = 0
        }
        if halo && !reduceMotion {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { haloLift = 8 }
        }
        do {
            switch pose {
            case .locked: try await sleepLoop()
            case .waiting: try await waitLoop()
            case .open: try await handOverLoop()
            case .resisted: try await swipeLoop()
            case .idle: try await idleLoop()
            case .noKey: break
            }
        } catch {}
    }

    @MainActor private func sleepLoop() async throws {
        withAnimation(.easeInOut(duration: 0.35)) { lidL = 2.1; lidR = 2.1 }
        try await Task.sleep(for: .seconds(0.3))
        shutL = true; shutR = true
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { breathe = 1.015; sway = 1.5 }
        while !Task.isCancelled {
            zPhase = 0
            withAnimation(.easeOut(duration: 2.6)) { zPhase = 1 }
            try await Task.sleep(for: .seconds(3.2))
        }
    }

    @MainActor private func waitLoop() async throws {
        var n = 0
        while !Task.isCancelled {
            try await Task.sleep(for: .seconds(1))
            n += 1
            if n % 3 == 0, !reduceMotion {
                withAnimation(.easeInOut(duration: 0.5)) { hourglassTurns += 1 }
            }
            if n % 4 == 0 { try await blink() }
        }
    }

    @MainActor private func handOverLoop() async throws {
        while !Task.isCancelled {
            try await Task.sleep(for: .seconds(0.8))
            if reduceMotion {
                try await blink()
                try await Task.sleep(for: .seconds(3))
                continue
            }
            keyInPaw = true
            paw = PawState(x: 130, y: 570, angle: 0, opacity: 1)
            withAnimation(.spring(duration: 0.7, bounce: 0.25)) { paw.y = 300 }
            try await Task.sleep(for: .seconds(1.0))
            withAnimation(.easeInOut(duration: 0.35)) { lidL = 2.1; lidR = 2.1 }
            try await Task.sleep(for: .seconds(0.3))
            shutL = true; shutR = true
            try await Task.sleep(for: .seconds(0.6))
            shutL = false; shutR = false
            withAnimation(.easeInOut(duration: 0.3)) { lidL = 1; lidR = 1 }
            try await Task.sleep(for: .seconds(0.4))
            withAnimation(.easeIn(duration: 0.5)) { paw.y = 570 }
            try await Task.sleep(for: .seconds(0.6))
            paw.opacity = 0; keyInPaw = false
            try await Task.sleep(for: .seconds(1.2))
        }
    }

    @MainActor private func idleLoop() async throws {
        while !Task.isCancelled {
            try await Task.sleep(for: .seconds(4))
            try await blink()
        }
    }

    @MainActor private func swipeLoop() async throws {
        while !Task.isCancelled {
            try await swipe()
            try await Task.sleep(for: .seconds(0.8))
        }
    }

    /// A slow, unbothered blink: about 200 ms down and up.
    @MainActor private func blink() async throws {
        withAnimation(.easeIn(duration: 0.1)) { lidL = 2.1; lidR = 2.1 }
        try await Task.sleep(for: .seconds(0.1))
        shutL = true; shutR = true
        try await Task.sleep(for: .seconds(0.08))
        shutL = false; shutR = false
        withAnimation(.easeOut(duration: 0.12)) { lidL = 1; lidR = 1 }
        try await Task.sleep(for: .seconds(0.15))
    }

    /// The swipe: the app comes for him, a paw floats in, winds up, bats it away, drifts back out.
    @MainActor private func swipe() async throws {
        if reduceMotion { try await blink(); return }
        tile = TileState(x: 600, y: 300, angle: 0, opacity: 0)
        withAnimation(.easeOut(duration: 0.55)) { tile.x = 402; tile.opacity = 1 }
        try await Task.sleep(for: .seconds(0.45))
        paw = PawState(x: -80, y: 310, angle: 0, opacity: 1)
        withAnimation(.easeOut(duration: 0.5)) { paw.x = 236 }
        try await Task.sleep(for: .seconds(0.5))
        withAnimation(.easeInOut(duration: 0.22)) { paw.x = 196; paw.y = 318; paw.angle = -18 }    // wind-up
        try await Task.sleep(for: .seconds(0.22))
        withAnimation(.easeOut(duration: 0.2)) { paw.x = 372; paw.y = 296; paw.angle = 24; lidL = 0.5; lidR = 0.5 }   // the bat
        try await Task.sleep(for: .seconds(0.12))
        withAnimation(.easeOut(duration: 0.4)) { tile.x = 640; tile.y = 160; tile.angle = 160 }
        try await Task.sleep(for: .seconds(0.3))
        tile.opacity = 0
        withAnimation(.easeInOut(duration: 0.4)) { paw.x = 330; paw.y = 306; paw.angle = 8 }
        try await Task.sleep(for: .seconds(0.4))
        withAnimation(.easeInOut(duration: 0.5)) { lidL = 1; lidR = 1 }
        withAnimation(.easeInOut(duration: 0.8)) { paw.x = -80; paw.y = 310; paw.angle = 0 }
        try await Task.sleep(for: .seconds(0.8))
        paw.opacity = 0
    }

    @MainActor private func tapped() {
        guard !swiping, pose != .noKey, pose != .resisted else { return }
        swiping = true
        Task {
            defer { swiping = false }
            if pose == .locked {
                // Woken up for a second: eyes open, swipe, back to sleep.
                shutL = false; shutR = false
                withAnimation(.easeOut(duration: 0.2)) { lidL = 1; lidR = 1 }
                try? await Task.sleep(for: .seconds(0.3))
                try? await swipe()
                withAnimation(.easeInOut(duration: 0.35)) { lidL = 2.1; lidR = 2.1 }
                try? await Task.sleep(for: .seconds(0.3))
                shutL = true; shutR = true
            } else {
                try? await swipe()
            }
        }
    }
}

/// Closed polygons in the 512 x 512 art space, scaled to the view's rect.
struct PolygonShape: Shape {
    let polygons: [[CGPoint]]
    func path(in rect: CGRect) -> Path {
        let k = min(rect.width, rect.height) / 512
        var p = Path()
        for poly in polygons where !poly.isEmpty {
            p.move(to: CGPoint(x: rect.minX + poly[0].x * k, y: rect.minY + poly[0].y * k))
            for pt in poly.dropFirst() { p.addLine(to: CGPoint(x: rect.minX + pt.x * k, y: rect.minY + pt.y * k)) }
            p.closeSubpath()
        }
        return p
    }
}

extension PawlMascotArt {
    static func color(_ rgb: UInt32) -> Color {
        Color(red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255, blue: Double(rgb & 0xFF) / 255)
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 16) {
            PawlMascot(pose: .locked)
            PawlMascot(pose: .waiting)
            PawlMascot(pose: .open)
        }
        HStack(spacing: 16) {
            PawlMascot(pose: .noKey)
            PawlMascot(pose: .resisted)
            PawlMascot(pose: .waiting, halo: true)
        }
    }
    .padding()
}
