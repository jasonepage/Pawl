// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  SupabaseClientProvider.swift
//  Pawl — Phase 2 backend
//
//  One shared SupabaseClient for the whole app (auth, PostgREST, RPC). Built from
//  SupabaseConfig (project URL + anon key). The anon key is RLS-protected, so it's safe
//  in the client (FR-P2-AUTH-004). Only the app target imports Supabase — never the
//  PawlMonitor / PawlShield extensions (they stay network-free on the hot path, HC-6).
//

import Foundation
import Supabase

public enum Supa {
    public static let client = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.anonKey
    )
}
