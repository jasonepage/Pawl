// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  ShieldConfigurationExtension.swift
//  PawlShield — Shield Configuration (ManagedSettingsUI) extension
//
//  Draws the custom block screen shown when the user opens a shielded app or site
//  (FR-SHIELD-007). Exposes NO button that lifts the shield (FR-SHIELD-008): the only
//  way out is the in-app key + cooling-off.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    // 2.3: the block screen uses the app's dark brand colors (Pawl/Theme/PawlTheme.swift:
    // cleanBg dark 0x1B3A0A and cleanText dark 0xC0DD97). The extension can't import the
    // app's theme, so the two values are repeated here.
    private static let forest = UIColor(red: 0x1B/255, green: 0x3A/255, blue: 0x0A/255, alpha: 1)
    private static let leaf = UIColor(red: 0xC0/255, green: 0xDD/255, blue: 0x97/255, alpha: 1)

    // Same App Group and key as SharedState in Pawl/Shared/PawlShared.swift. That file is not
    // in this target, so the two strings are repeated. The shield action extension writes a
    // timestamp here each time someone presses either button, so each one is a time they
    // walked away instead of opening the app.
    private static let appGroup = "group.io.github.jasonepage.Pawl"
    private static let attemptsKey = "pawl.shield.attempts"

    /// The app icon, dressed up for a dark screen: a soft leaf-green glow, the icon on a
    /// rounded tile with a drop shadow, and a thin light edge. The icon is a PNG in this
    /// extension's own bundle (ShieldIcon.png), since the extension cannot read the app's
    /// asset catalog. Without an icon, iOS shows its generic blue Screen Time hourglass.
    private static let mark: UIImage = {
        let size = CGSize(width: 120, height: 120)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            let space = CGColorSpaceCreateDeviceRGB()
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let glowColor = ShieldConfigurationExtension.leaf

            // 1. Glow behind the tile.
            if let glow = CGGradient(colorsSpace: space,
                                     colors: [glowColor.withAlphaComponent(0.45).cgColor,
                                              glowColor.withAlphaComponent(0).cgColor] as CFArray,
                                     locations: [0, 1]) {
                cg.drawRadialGradient(glow, startCenter: center, startRadius: 30,
                                      endCenter: center, endRadius: 60, options: [])
            }

            // 2. The tile, with a drop shadow.
            let tile = CGRect(x: 14, y: 14, width: 92, height: 92)
            let tilePath = UIBezierPath(roundedRect: tile, cornerRadius: 21)
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: 4), blur: 10,
                         color: UIColor.black.withAlphaComponent(0.4).cgColor)
            UIColor(red: 0.08, green: 0.14, blue: 0.08, alpha: 1).setFill()
            tilePath.fill()
            cg.restoreGState()

            // 3. The icon, clipped to the tile.
            cg.saveGState()
            tilePath.addClip()
            if let path = Bundle.main.path(forResource: "ShieldIcon", ofType: "png"),
               let icon = UIImage(contentsOfFile: path) {
                icon.draw(in: tile)
            }
            cg.restoreGState()

            // 4. A thin light edge.
            let edge = UIBezierPath(roundedRect: tile.insetBy(dx: 0.75, dy: 0.75), cornerRadius: 20.25)
            edge.lineWidth = 1.5
            UIColor(white: 1, alpha: 0.2).setStroke()
            edge.stroke()
        }
        return image.withRenderingMode(.alwaysOriginal)
    }()

    /// "Instagram is locked" when iOS gives us the name, otherwise "Locked by Pawl".
    private static func title(for name: String?) -> String {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return "Locked by Pawl"
        }
        return "\(name) is locked"
    }

    /// Presses on this screen in the last seven days. Each one is a time the person walked
    /// away. Counting only ever rewards walking away, never a slip.
    private static func walkedAwayThisWeek(now: Date = Date()) -> Int {
        let stamps = (UserDefaults(suiteName: appGroup)?.array(forKey: attemptsKey) as? [Double]) ?? []
        let cutoff = now.timeIntervalSince1970 - 7 * 24 * 60 * 60
        return stamps.filter { $0 >= cutoff }.count
    }

    private static func subtitle() -> String {
        // 2.4: say the two real ways out, plainly. Nothing else opens this.
        let base = "To open this app, plug in the key you paired with Pawl, or turn off Screen Time for Pawl."
        switch walkedAwayThisWeek() {
        case 0: return base
        case 1: return base + "\n\nYou walked away once this week."
        case let n: return base + "\n\nYou've walked away \(n) times this week."
        }
    }

    private func pawlConfiguration(name: String?) -> ShieldConfiguration {
        ShieldConfiguration(
            // No blur: a solid color reads cleaner than green tinted over the app behind it.
            backgroundBlurStyle: nil,
            backgroundColor: Self.forest,
            icon: Self.mark,
            title: ShieldConfiguration.Label(text: Self.title(for: name), color: .white),
            subtitle: ShieldConfiguration.Label(text: Self.subtitle(),
                                                color: UIColor(white: 1, alpha: 0.78)),
            // Neither button lifts the shield (FR-SHIELD-008). "Close this app" returns to the
            // home screen. "I need a minute" does the same, and additionally leaves a note that
            // makes Pawl open the urge flow the next time it launches (FR-SHACT-004).
            // Both presses are counted (FR-SHACT-002). Handled in PawlShieldAction.
            // Primary colors are set explicitly. Left unset, iOS fills the button with its own
            // light blue, and white text on it is hard to read.
            primaryButtonLabel: ShieldConfiguration.Label(text: "Close this app", color: Self.forest),
            primaryButtonBackgroundColor: Self.leaf
            // 2.4: no second button. The "I'm tempted" flow is gone from the block screen.
        )
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        pawlConfiguration(name: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        pawlConfiguration(name: application.localizedDisplayName ?? category.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        pawlConfiguration(name: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        pawlConfiguration(name: webDomain.domain)
    }
}
