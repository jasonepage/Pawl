// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  ShieldActionExtension.swift
//  PawlShieldAction
//
//  Created by Jason Page on 9/2/26.
//
//  Runs when someone presses a button on the "Locked by Pawl" block screen. That press is
//  the urge. It is the moment this whole product exists for, and until now Pawl threw it
//  away: the shield had no buttons and the app learned nothing.
//
//  What this must NEVER do: lift the shield. The only way out of a shield is still the
//  physical key plus the cooling off window, inside the app (FR-SHIELD-008).
//
//  Two changes from the Xcode template, both deliberate:
//    1. The template returns .defer for the secondary button. Defer leaves the blocked app
//       open behind the shield. Pawl returns .close on every path, so the person is put back
//       on the home screen and out of the app they were trying to open.
//    2. The template calls fatalError() in @unknown default. Pawl never crashes here.
//
//  Deployment target is iOS 18, the same as the app (2.1; it was 26.5 by accident, which
//  left the block screen buttons dead on iOS 18 through 26.4). The submenu actions are not
//  named in the switch, so this compiles on the iOS 18 SDK floor: anything that is not the
//  primary button is treated as the secondary button, which opens the urge flow.
//
//  Setup that must be true or this silently does nothing:
//    * App Group group.io.github.jasonepage.Pawl on this target (writes go to the wrong
//      suite otherwise, with no error anywhere).
//    * PawlShared.swift ticked into this target's membership, making it four targets.
//
//  Spec: docs/16_SRS_SDS_ShieldActions_and_PartnerCodes.md
//

import Foundation
import ManagedSettings

class ShieldActionExtension: ShieldActionDelegate {

    /// Every press is a caught attempt (FR-SHACT-002). The secondary button additionally
    /// leaves a note for the app to open the urge flow on next launch (FR-SHACT-004).
    ///
    /// iOS gives an extension no supported way to open its containing app, so the handoff is
    /// deferred rather than immediate. That is a real platform limit, not an oversight.
    private func respond(to action: ShieldAction) -> ShieldActionResponse {
        SharedState.recordBlockAttempt()

        switch action {
        case .primaryButtonPressed:
            break
        default:
            // The secondary button, its submenu items on newer iOS, and any action a future
            // iOS adds. All of them mean somebody hit the shield and asked for help, so leave
            // the note for the urge flow. Never crash here.
            SharedState.setPendingUrge()
        }

        return .close
    }

    override func handle(action: ShieldAction,
                         for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action))
    }

    override func handle(action: ShieldAction,
                         for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action))
    }

    override func handle(action: ShieldAction,
                         for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action))
    }
}
