// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  ScreenshotMode.swift
//  Pawl — App Store screenshot mode (Xcode Debug builds only)
//
//  Turned on from Settings > Developer. After a relaunch the app looks fully set up so App
//  Store screenshots can be taken in the Simulator, where a security key cannot be paired:
//  Home shows a paired key, a full protected week and no notes; on the Unlock tab, tapping
//  the big status card cycles Blocked, Waiting and Open. Nothing here touches the shield,
//  the key store or iCloud. Never compiled into Release.
//

#if DEBUG
import Foundation

enum ScreenshotMode {
    static let defaultsKey = "pawl.screenshotMode"
    static var isOn: Bool { UserDefaults.standard.bool(forKey: defaultsKey) }
}
#endif
