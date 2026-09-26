// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  AccountView.swift
//  Pawl — Phase 2 (slice 1: auth)
//
//  The Account section in Settings. Signed out → Sign in with Apple. Signed in → status +
//  Sign out. Intentionally additive: the blocker works without an account, and this never
//  gates the app (FR-P2-AUTH-005/006). Sponsor linking hangs off this in the next slice.
//

import SwiftUI
import AuthenticationServices

struct AccountView: View {
    let auth: AuthService
    /// Fired after a successful sign-in so the app can push/reconcile commitment state.
    var onSignIn: (() -> Void)? = nil
    @State private var nameDraft = ""
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false

    var body: some View {
        Section("Account") {
            if auth.isSignedIn {
                LabeledContent("Signed in", value: auth.email ?? "Apple ID")
                HStack(spacing: 12) {
                    Text("Your name")
                    Spacer(minLength: 8)
                    TextField("Add your name", text: $nameDraft)
                        .multilineTextAlignment(.trailing)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { Task { await auth.updateDisplayName(nameDraft) } }
                }
                let trimmed = nameDraft.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty && trimmed != (auth.displayName ?? "") {
                    Button("Save name") { Task { await auth.updateDisplayName(nameDraft) } }
                }
                if (auth.displayName ?? "").isEmpty {
                    Text("Add your name so your sponsor sees it's you — otherwise you appear as \u{201C}Someone you sponsor.\u{201D}")
                        .font(.caption).foregroundStyle(PawlColor.brand)
                } else {
                    Text("Your sponsor sees this name on their alerts and requests.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button("Sign out") {
                    Task { await auth.signOut() }
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    if isDeleting {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Deleting\u{2026}")
                        }
                    } else {
                        Text("Delete account\u{2026}")
                    }
                }
                .disabled(isDeleting)
                Text("Deleting your account removes your profile, sponsor link, and all accountability history from our servers. Your on-device protection and clean-day streak stay on this iPhone. This can't be undone.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                SignInWithAppleButton(.signIn) { request in
                    auth.configure(request)
                } onCompletion: { result in
                    Task {
                        await auth.handle(result)
                        if auth.isSignedIn { onSignIn?() }
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 44)

                Text("Sign in to link a sponsor and turn on accountability. The blocker works without an account — signing out never lifts your shield.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let message = auth.message {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .onAppear { if nameDraft.isEmpty { nameDraft = auth.displayName ?? "" } }
        .onChange(of: auth.displayName) { _, new in if nameDraft.isEmpty { nameDraft = new ?? "" } }
        .alert("Delete your account?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete account", role: .destructive) {
                isDeleting = true
                Task {
                    await auth.deleteAccount()
                    isDeleting = false
                }
            }
        } message: {
            Text("This permanently deletes your Pawl account, profile, sponsor link, and all accountability history from our servers. It can't be undone.\n\nYour on-device protection and clean-day streak stay on this iPhone.")
        }
    }
}
