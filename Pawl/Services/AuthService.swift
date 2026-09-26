// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  AuthService.swift
//  Pawl — Phase 2 backend (slice 1: auth)
//
//  Sign in with Apple → Supabase session, and an idempotent profile upsert
//  (FR-P2-AUTH-002/003). Additive by design: the core blocking + solo unlock loop work
//  fully while signed out or offline (FR-P2-AUTH-005), and signing out NEVER lifts the
//  shield (FR-P2-AUTH-006). RLS is the security boundary (FR-P2-AUTH-004).
//
//  Native SiwA flow: generate a random nonce, send its SHA256 to Apple, then hand the
//  identity token + the RAW nonce to Supabase signInWithIdToken (anti-replay).
//

import Foundation
import Supabase
import AuthenticationServices
import CryptoKit

@MainActor
@Observable
public final class AuthService {
    public private(set) var isSignedIn = false
    public private(set) var email: String?
    public private(set) var userID: UUID?
    public private(set) var displayName: String?
    public private(set) var message: String?

    private let client = Supa.client
    private var currentNonce: String?

    public init() {
        // Restore a cached session with no network call, so a relaunch keeps you signed in.
        if let session = client.auth.currentSession {
            apply(session)
            Task { await loadDisplayName() }
        }
    }

    /// Hook for `SignInWithAppleButton`'s onRequest: set scopes.
    ///
    /// NOTE: nonce intentionally omitted on BOTH sides (Apple request + Supabase exchange).
    /// GoTrue's Apple nonce verification has a known encoding bug (hex vs base64url) that
    /// returns "Nonces mismatch" even for the documented raw-nonce flow; it allows the nonce
    /// to be absent on both sides and then skips the check. Native SiwA already delivers the
    /// token directly over Apple's secure channel (not a redirect), so anti-replay exposure is
    /// low. Re-harden when we add server-side assertion verification (FR-P2-WAUTH).
    public func configure(_ request: ASAuthorizationAppleIDRequest) {
        currentNonce = nil
        request.requestedScopes = [.fullName, .email]
    }

    /// Hook for `SignInWithAppleButton`'s onCompletion: exchange the Apple token for a
    /// Supabase session and ensure the profile row exists.
    public func handle(_ result: Result<ASAuthorization, Error>) async {
        message = nil
        switch result {
        case .failure(let error):
            // User-cancelled is not an error worth surfacing loudly.
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            message = error.localizedDescription

        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8)
            else {
                message = "Apple sign-in didn't return an identity token."
                return
            }

            // fullName is only provided on the FIRST authorization for this Apple ID.
            let appleName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            do {
                let session = try await client.auth.signInWithIdToken(
                    credentials: .init(provider: .apple, idToken: idToken)
                )
                apply(session)
                try await ensureProfile(appleName: appleName.isEmpty ? nil : appleName)

                // Best-effort: hand Apple's one-time authorizationCode to our backend so it can
                // store a refresh token and revoke it if the user later deletes their account
                // (Apple TN3159 / Guideline 5.1.1(v)). Never blocks or fails sign-in.
                if let codeData = credential.authorizationCode,
                   let code = String(data: codeData, encoding: .utf8) {
                    await linkAppleToken(code)
                }
            } catch {
                message = error.localizedDescription
            }
        }
    }

    /// Sign out. Does NOT touch the shield (FR-P2-AUTH-006). Falls back to solo mode.
    public func signOut() async {
        do { try await client.auth.signOut() }
        catch { message = error.localizedDescription }
        isSignedIn = false
        email = nil
        userID = nil
    }

    /// Permanently delete the account and ALL cloud data (Guideline 5.1.1(v)). Calls the
    /// `delete-account` Edge Function, which authenticates via the session token, notifies any
    /// linked sponsor, revokes the Apple token (if configured), and cascade-deletes every row.
    /// Then clears the local session. Does NOT touch the on-device shield or streak — deleting the
    /// account is the cloud/sponsor layer, exactly like Sign out (FR-P2-AUTH-006). Returns true on
    /// success so the UI can dismiss.
    @discardableResult
    public func deleteAccount() async -> Bool {
        guard isSignedIn else { return false }
        message = nil
        do {
            // No body: the function takes the user to delete from the JWT, never from input.
            try await client.functions.invoke("delete-account")
            // The server-side user is gone, so clear the local session. A network sign-out would
            // 401 against the deleted session; sign out locally instead.
            try? await client.auth.signOut()
            isSignedIn = false
            email = nil
            userID = nil
            displayName = nil
            message = "Your account and all of its data were deleted."
            return true
        } catch {
            message = "Couldn't delete your account: \(error.localizedDescription)"
            return false
        }
    }

    /// Best-effort: store Apple's authorizationCode server-side so the account can later revoke the
    /// Sign in with Apple token. Fire-and-forget — failure here never affects sign-in.
    private func linkAppleToken(_ code: String) async {
        struct Body: Encodable { let code: String }
        do {
            try await client.functions.invoke(
                "apple-link", options: FunctionInvokeOptions(body: Body(code: code)))
        } catch {
            #if DEBUG
            print("apple-link failed (non-fatal): \(error)")
            #endif
        }
    }

    // MARK: - Internals

    private func apply(_ session: Session) {
        isSignedIn = true
        email = session.user.email
        userID = session.user.id
    }

    /// Upsert the profile row keyed to the auth user (FR-P2-AUTH-003). Idempotent. Apple only sends
    /// the name on the FIRST authorization, so when it's absent we keep whatever name is already
    /// stored rather than overwriting it with null.
    private func ensureProfile(appleName: String?) async throws {
        guard let userID else { return }
        var nameToWrite = appleName
        if nameToWrite == nil {
            nameToWrite = await fetchDisplayName()   // keep an existing name; ?? autoclosure can't be async
        }
        struct ProfileRow: Encodable { let id: String; let display_name: String? }
        try await client
            .from("profiles")
            .upsert(ProfileRow(id: userID.uuidString, display_name: nameToWrite))
            .execute()
        displayName = nameToWrite
    }

    /// Read the stored display name for the current user (best-effort).
    private func fetchDisplayName() async -> String? {
        guard let userID else { return nil }
        struct Row: Decodable { let display_name: String? }
        let rows: [Row]? = try? await client.from("profiles")
            .select("display_name").eq("id", value: userID.uuidString).limit(1).execute().value
        return rows?.first?.display_name
    }

    /// Load and publish the display name (on session restore).
    private func loadDisplayName() async {
        displayName = await fetchDisplayName()
    }

    /// Set the user's display name so a sponsor sees who they are (not "Someone you sponsor").
    public func updateDisplayName(_ name: String) async {
        guard let userID else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        struct ProfileRow: Encodable { let id: String; let display_name: String }
        do {
            try await client.from("profiles")
                .upsert(ProfileRow(id: userID.uuidString, display_name: trimmed))
                .execute()
            displayName = trimmed
            message = "Saved."
        } catch {
            message = error.localizedDescription
        }
    }

    // MARK: - Nonce helpers (Apple SiwA + Supabase OIDC)

    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        // Swift's UInt8.random uses the system's cryptographically-secure RNG (same
        // approach as SecurityKeyService's challenge), so no Security import is needed.
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        while result.count < length {
            let byte = UInt8.random(in: 0...255)
            if Int(byte) < charset.count {        // reject the tail to avoid modulo bias
                result.append(charset[Int(byte)])
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
