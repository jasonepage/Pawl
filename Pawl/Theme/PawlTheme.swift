// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  PawlTheme.swift
//  Pawl — design system
//
//  A small, accessible theme: a calm green/amber/red palette that adapts to light
//  and dark mode, reusable button + card styling, and type that scales with the
//  user's Dynamic Type setting. Built for legibility (high contrast, big targets)
//  so it works for older users and at the moment of urge.
//

import SwiftUI
import UIKit

// MARK: - Palette (adaptive light/dark)

public enum PawlColor {
    /// Build a color that swaps between a light-mode and dark-mode hex.
    static func adaptive(light: UInt, dark: UInt) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    // Clean / protected (green): calm, positive.
    public static let cleanBg   = adaptive(light: 0xEAF3DE, dark: 0x1B3A0A)
    public static let cleanText = adaptive(light: 0x27500A, dark: 0xC0DD97)
    /// Brand accent (tab tint, links).
    public static let brand     = adaptive(light: 0x3B6D11, dark: 0x97C459)

    // Urge / help (amber): warm and findable, not alarming.
    public static let urgeBg    = adaptive(light: 0xFAE2B5, dark: 0x4A2A05)
    public static let urgeText  = adaptive(light: 0x633806, dark: 0xFAC775)

    // Relapse (red): reserved, never used for anything positive.
    public static let dangerText = adaptive(light: 0xA32D2D, dark: 0xF09595)

    // Surfaces (system, so they're correct in both modes automatically).
    public static let groupedBg = Color(uiColor: .systemGroupedBackground)
    public static let cardBg    = Color(uiColor: .secondarySystemGroupedBackground)
}

extension UIColor {
    convenience init(rgb: UInt) {
        self.init(
            red:   CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue:  CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Big primary button (large tap target, scales with Dynamic Type)

public struct PawlBigButtonStyle: ButtonStyle {
    var background: Color
    var foreground: Color

    public init(background: Color, foreground: Color) {
        self.background = background
        self.foreground = foreground
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.title3, design: .rounded).weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 30)
            .padding(.vertical, 18)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .contentShape(Rectangle())
    }
}

// MARK: - Text field (labelled, filled — not the stock rounded-border look)

public struct PawlField: View {
    let title: String
    let prompt: String
    @Binding var text: String
    var multiline: Bool

    public init(_ title: String, prompt: String, text: Binding<String>, multiline: Bool = false) {
        self.title = title
        self.prompt = prompt
        self._text = text
        self.multiline = multiline
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Group {
                if multiline {
                    TextField(prompt, text: $text, axis: .vertical).lineLimit(2...4)
                } else {
                    TextField(prompt, text: $text)
                }
            }
            .font(.body)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

// MARK: - Card container

public struct PawlCard<Content: View>: View {
    @ViewBuilder var content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PawlColor.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
