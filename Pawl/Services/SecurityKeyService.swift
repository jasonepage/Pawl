// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  SecurityKeyService.swift
//  Pawl — iOS integration layer
//
//  The physical key, implemented as a USB-C (or NFC/Lightning) FIDO2 security key via
//  Apple's AuthenticationServices / WebAuthn APIs. This replaces the passive NFC tag.
//  HC-4/HC-7 still hold: the key only gates the in-app unshield and is the object the
//  user puts out of reach; it is NOT a substitute for the Screen Time passcode.
//
//  REQUIREMENT: `PawlConfig.relyingPartyID` must be a domain you own, configured as an
//  Associated Domain (webcredentials:<domain>) with an apple-app-site-association file
//  hosted on it. Without that, iOS rejects these requests. See docs/05_Security_Key_Setup.md.
//
//  Phase-1 model: we don't run a server, so we don't verify assertion signatures. We
//  store the registered credential ID and, to unlock, require an assertion that returns
//  the SAME credential ID — i.e. proof the same physical key is present. Good enough for
//  the "possession" gate (HC-7); real cryptographic verification can come with the backend.
//

import Foundation
import AuthenticationServices
import UIKit

@MainActor
public final class SecurityKeyService: NSObject {

    public enum SecurityKeyError: LocalizedError {
        case cancelled
        case noCredential
        case failed(String)

        public var errorDescription: String? {
            switch self {
            case .cancelled:    return "Cancelled."
            case .noCredential: return "The key didn't return a credential."
            case .failed(let why):
                return "Security key error: \(why)\n(If this mentions the domain/relying party, the Associated Domain isn't set up yet — see the setup doc.)"
            }
        }
    }

    private let relyingPartyID: String
    private var continuation: CheckedContinuation<Data, Error>?
    private var controller: ASAuthorizationController?

    public init(relyingPartyID: String = PawlConfig.relyingPartyID) {
        self.relyingPartyID = relyingPartyID
    }

    /// Register a new security key; returns its credential ID to store as the key identity.
    public func register(displayName: String) async throws -> Data {
        let provider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(relyingPartyIdentifier: relyingPartyID)
        let request = provider.createCredentialRegistrationRequest(
            challenge: Self.randomChallenge(),
            displayName: displayName,
            name: displayName,
            userID: Data(UUID().uuidString.utf8)
        )
        request.credentialParameters = [ASAuthorizationPublicKeyCredentialParameters(algorithm: .ES256)]
        request.userVerificationPreference = .preferred
        return try await perform(request)
    }

    /// Prove possession of a previously registered key; returns the credential ID used.
    public func assert() async throws -> Data {
        let provider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(relyingPartyIdentifier: relyingPartyID)
        let request = provider.createCredentialAssertionRequest(challenge: Self.randomChallenge())
        request.userVerificationPreference = .preferred
        return try await perform(request)
    }

    private func perform(_ request: ASAuthorizationRequest) async throws -> Data {
        try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.controller = controller
            controller.performRequests()
        }
    }

    private func finish(_ result: Result<Data, Error>) {
        guard let cont = continuation else { return }
        continuation = nil
        controller = nil
        cont.resume(with: result)
    }

    private static func randomChallenge() -> Data {
        Data((0..<32).map { _ in UInt8.random(in: 0...255) })
    }
}

extension SecurityKeyService: ASAuthorizationControllerDelegate {
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let reg = authorization.credential as? ASAuthorizationSecurityKeyPublicKeyCredentialRegistration {
            finish(.success(reg.credentialID))
        } else if let assertion = authorization.credential as? ASAuthorizationSecurityKeyPublicKeyCredentialAssertion {
            finish(.success(assertion.credentialID))
        } else {
            finish(.failure(SecurityKeyError.noCredential))
        }
    }

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let asError = error as? ASAuthorizationError, asError.code == .canceled {
            finish(.failure(SecurityKeyError.cancelled))
        } else {
            finish(.failure(SecurityKeyError.failed((error as NSError).localizedDescription)))
        }
    }
}

extension SecurityKeyService: ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        if let window = scene?.keyWindow { return window }
        if let scene { return UIWindow(windowScene: scene) }      // iOS 26: init() is deprecated
        return UIWindow(frame: .zero)
    }
}
