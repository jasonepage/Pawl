// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  PadColumns.swift
//  Pawl — iPad layout for the main tabs
//
//  iPad (regular width): two columns side by side, wider margins, and a text size floor of
//  xLarge so the screen does not read like a stretched phone. Larger Dynamic Type sizes the
//  person chose still win. iPhone and split-screen iPad (compact width): one column with the
//  same 20 point padding as before, so nothing changes there.
//

import SwiftUI

struct PadColumns<Leading: View, Trailing: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    private let spacing: CGFloat
    private let leading: Leading
    private let trailing: Trailing

    init(spacing: CGFloat = 16,
         @ViewBuilder leading: () -> Leading,
         @ViewBuilder trailing: () -> Trailing) {
        self.spacing = spacing
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        if sizeClass == .regular {
            HStack(alignment: .top, spacing: 28) {
                VStack(spacing: spacing) { leading }
                    .frame(maxWidth: .infinity)
                VStack(spacing: spacing) { trailing }
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: 1100)
            .padding(.horizontal, 36)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
            .dynamicTypeSize(DynamicTypeSize.xLarge...)
        } else {
            VStack(spacing: spacing) {
                leading
                trailing
            }
            .padding(20)
        }
    }
}

extension View {
    /// iPad (regular width): keep a single-column screen at a comfortable reading width,
    /// centered, with the same text size floor as PadColumns. iPhone: unchanged.
    func padReadableWidth(_ width: CGFloat = 720) -> some View {
        modifier(PadReadableWidth(width: width))
    }
}

private struct PadReadableWidth: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    let width: CGFloat

    func body(content: Content) -> some View {
        if sizeClass == .regular {
            content
                .frame(maxWidth: width)
                .frame(maxWidth: .infinity)
                .dynamicTypeSize(DynamicTypeSize.xLarge...)
        } else {
            content
        }
    }
}
