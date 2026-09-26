// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  AuthorizationService.swift
//  Pawl — iOS integration layer
//
//  Wraps FamilyControls authorization (SDS §2.1; SRS FR-AUTH-001..005).
//  HC-1: blocking is only possible via the Screen Time API, which requires this
//  authorization. HC-3: shipping requires the Family Controls (Distribution)
//  entitlement from Apple — see docs/04_Xcode_Setup_Checklist.md.
//
//  NOTE: Screen Time authorization + the picker only work on a REAL DEVICE, not
//  the simulator, and only once the Family Controls capability is added in Xcode.
//

import Foundation
import FamilyControls

@MainActor
@Observable
public final class AuthorizationService {
    public private(set) var status: AuthorizationStatus
    /// Last failure reason, surfaced in the UI. A common one early on is the
    /// missing Family Controls capability/entitlement (HC-3) — see the checklist.
    public private(set) var lastErrorMessage: String?

    private let center = AuthorizationCenter.shared

    public init() {
        self.status = center.authorizationStatus
    }

    /// FR-AUTH-001: request `.individual` authorization (single device, no MDM).
    public func requestAuthorization() async {
        lastErrorMessage = nil
        do {
            try await center.requestAuthorization(for: .individual)
        } catch {
            // Surface it instead of swallowing, so a missing entitlement is visible.
            lastErrorMessage = (error as NSError).localizedDescription
        }
        status = center.authorizationStatus
    }

    /// FR-AUTH-003: on launch, refresh status. If an active commitment exists but
    /// status is not `.approved`, the caller should enter the Authorization-Lost
    /// state (SDS §6, EDGE-AUTH) — protection is down until re-granted (HC-6).
    public func refresh() {
        status = center.authorizationStatus
    }

    public var isApproved: Bool { status == .approved }
}
