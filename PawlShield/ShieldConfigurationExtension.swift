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

    private func pawlConfiguration() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 53/255, green: 99/255, blue: 16/255, alpha: 1),
            icon: nil,
            title: ShieldConfiguration.Label(text: "Locked by Pawl", color: .white),
            subtitle: ShieldConfiguration.Label(
                text: "Open Pawl and use your security key, then wait out the cooling-off. No shortcuts at 1am.",
                color: UIColor(white: 1, alpha: 0.85)
            ),
            // Neither button lifts the shield (FR-SHIELD-008). "Close this app" returns to the
            // home screen. "I need a minute" does the same, and additionally leaves a note that
            // makes Pawl open the urge flow the next time it launches (FR-SHACT-004).
            // Both presses are counted (FR-SHACT-002). Handled in PawlShieldAction.
            primaryButtonLabel: ShieldConfiguration.Label(text: "Close this app", color: .white),
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "I need a minute",
                color: UIColor(white: 1, alpha: 0.85)
            )
        )
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        pawlConfiguration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        pawlConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        pawlConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        pawlConfiguration()
    }
}
