// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  PawlConfig.swift
//  Pawl
//
//  App-wide configuration constants.
//

import Foundation

public enum PawlConfig {
    /// The Relying Party ID for security-key (WebAuthn) auth. This MUST be a domain
    /// you own and that is set up as an Associated Domain (`webcredentials:<this>`),
    /// with an apple-app-site-association file hosted at
    /// https://<this>/.well-known/apple-app-site-association
    /// See docs/05_Security_Key_Setup.md. Until that's live, register/assert will fail.
    // `nonisolated` so it can be read from any context (e.g. as a default argument),
    // not just the main actor under the project's main-actor-by-default mode.
    public nonisolated static let relyingPartyID = "getpawl.com"
}
