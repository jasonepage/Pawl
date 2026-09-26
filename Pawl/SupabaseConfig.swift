// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  SupabaseConfig.swift
//  Pawl — Phase 2 configuration
//
//  Project connection values for the `pawl` Supabase project (ref bvixxdlmjeulxrefmqjx,
//  region us-east-2). The anon key is designed to ship in the client — Row-Level Security
//  is the security boundary, not key secrecy (FR-P2-AUTH-004). The service_role key must
//  NEVER appear here; it lives only in Edge Function secrets.
//
//  Plain constants on purpose: no `import Supabase`, so this file is safe to add before
//  the supabase-swift package is installed. The SupabaseClient bootstrap lands once the
//  package is in the target (see docs/09 §6).
//

import Foundation

public enum SupabaseConfig {
    /// REST/Auth base URL, derived from the project ref.
    public static let url = URL(string: "https://bvixxdlmjeulxrefmqjx.supabase.co")!

    /// Publishable `anon` key (RLS-protected; safe in-app). Rotate via Dashboard → API Keys.
    public static let anonKey =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ2aXh4ZGxtamV1bHhyZWZtcWp4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIxNTk3NDMsImV4cCI6MjA5NzczNTc0M30.xOytYjZNOA9ME_NM8udTNlj6RckB3dDLKSlAcFMwf6w"

    /// Background-task identifier for the opportunistic heartbeat (must match the
    /// `BGTaskSchedulerPermittedIdentifiers` Info.plist entry — docs/09 §6).
    public static let heartbeatTaskID = "io.github.jasonepage.Pawl.heartbeat"
}
