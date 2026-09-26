// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  SecurityKeyService.swift
//  Pawl — iOS integration layer
//
//  The physical key, implemented as a USB-C (or NFC/Lightning) FIDO2 security key via
//  Apple's AuthenticationServices / WebAuthn APIs. HC-4/HC-7 still hold: the key only gates
//  the in-app unshield and is the object the user puts out of reach; it is NOT a substitute
//  for the Screen Time passcode.
//
//  REQUIREMENT: `PawlConfig.relyingPartyID` must be a domain you own, configured as an
//  Associated Domain (webcredentials:<domain>) with an apple-app-site-association file
//  hosted on it. Without that, iOS rejects these requests. See docs/05_Security_Key_Setup.md.
//
//  2.1: this file no longer throws away what the key returns. Every request gets a fresh
//  32-byte challenge, and the full response is checked by WebAuthnVerifier (Pawl/Domain):
//  challenge binding, relying party hash, User Present flag, signature counter, and the ES256
//  signature against the public key captured at pairing. The 2.0 check (credential ID match)
//  is still part of it. What remains unverified is listed at the top of WebAuthnVerifier.swift.
//

import Foundation
import AuthenticationServices
import Security
import UIKit

/// Everything a registration returns, plus the challenge we issued for it.
public struct KeyRegistration: Sendable {
    public let credentialID: Data
    public let rawClientDataJSON: Data
    /// CBOR attestation object; holds authenticatorData with the new public key.
    public let rawAttestationObject: Data?
    public let challenge: Data
}

/// Everything an assertion returns, plus the challenge we issued for it.
public struct KeyAssertion: Sendable {
    public let credentialID: Data
    public let rawClientDataJSON: Data
    public let rawAuthenticatorData: Data
    public let signature: Data
    public let userID: Data
    public let challenge: Data
}

/// The outcome of checking a key tap against the paired key.
public enum KeyPresence: Sendable {
    /// Every check passed. Store `updated` (its signature counter moved forward).
    case verified(updated: RegisteredKey)
    /// The key answered, but a check failed. Treat exactly like "not your paired key".
    case rejected(WebAuthnError)
}

@MainActor
public final class SecurityKeyService: NSObject {

    public enum SecurityKeyError: LocalizedError {
        case cancelled
        case noCredential
        case failed(String)
        case registrationRejected(WebAuthnError)

        public var errorDescription: String? {
            switch self {
            case .cancelled:    return "Cancelled."
            case .noCredential: return "The key didn't return a credential."
            case .failed(let why):
                return "Security key error: \(why)\n(If this mentions the domain/relying party, the Associated Domain isn't set up yet — see the setup doc.)"
            case .registrationRejected(let why):
                return "That key's pairing response didn't pass the check (\(why)). Nothing was saved. Try again."
            }
        }
    }

    /// What the delegate hands back, copied into Sendable values.
    private enum RawCredential: Sendable {
        case registration(credentialID: Data, clientDataJSON: Data, attestationObject: Data?)
        case assertion(credentialID: Data, clientDataJSON: Data, authenticatorData: Data, signature: Data, userID: Data)
    }

    private let relyingPartyID: String
    private var continuation: CheckedContinuation<RawCredential, Error>?
    private var controller: ASAuthorizationController?

    public init(relyingPartyID: String = PawlConfig.relyingPartyID) {
        self.relyingPartyID = relyingPartyID
    }

    // MARK: - High level (what the app calls)

    /// Pair a new key: register it, verify the registration, and return what to store.
    public func pairNewKey(displayName: String) async throws -> RegisteredKey {
        let registration = try await register(displayName: displayName)
        guard let attestationObject = registration.rawAttestationObject else {
            throw SecurityKeyError.registrationRejected(.malformedAttestationObject)
        }
        do {
            return try WebAuthnVerifier.verifyRegistration(
                credentialID: registration.credentialID,
                clientDataJSON: registration.rawClientDataJSON,
                attestationObject: attestationObject,
                challenge: registration.challenge,
                relyingPartyID: relyingPartyID
            )
        } catch let error as WebAuthnError {
            throw SecurityKeyError.registrationRejected(error)
        }
    }

    /// Ask for a key tap and check it against the paired key (FR-UNLOCK-002).
    /// Throws only when the tap didn't happen (cancelled, OS error). A tap that fails a check
    /// comes back as `.rejected`, so callers keep the same "not your key" path as 2.0.
    public func verifyPresence(of paired: RegisteredKey) async throws -> KeyPresence {
        let assertion = try await assert()
        do {
            let updated = try WebAuthnVerifier.verifyAssertion(
                credentialID: assertion.credentialID,
                clientDataJSON: assertion.rawClientDataJSON,
                authenticatorData: assertion.rawAuthenticatorData,
                signature: assertion.signature,
                challenge: assertion.challenge,
                relyingPartyID: relyingPartyID,
                registered: paired
            )
            return .verified(updated: updated)
        } catch let error as WebAuthnError {
            return .rejected(error)
        }
    }

    // MARK: - Raw requests

    /// Register a new security key. Returns the full, unverified response.
    public func register(displayName: String) async throws -> KeyRegistration {
        let challenge = Self.randomChallenge()
        let provider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(relyingPartyIdentifier: relyingPartyID)
        let request = provider.createCredentialRegistrationRequest(
            challenge: challenge,
            displayName: displayName,
            name: displayName,
            userID: Data(UUID().uuidString.utf8)
        )
        request.credentialParameters = [ASAuthorizationPublicKeyCredentialParameters(algorithm: .ES256)]
        request.userVerificationPreference = .preferred
        guard case let .registration(id, clientData, attestation) = try await perform(request) else {
            throw SecurityKeyError.noCredential
        }
        return KeyRegistration(credentialID: id, rawClientDataJSON: clientData,
                               rawAttestationObject: attestation, challenge: challenge)
    }

    /// Ask for an assertion from a registered key. Returns the full, unverified response.
    public func assert() async throws -> KeyAssertion {
        let challenge = Self.randomChallenge()
        let provider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(relyingPartyIdentifier: relyingPartyID)
        let request = provider.createCredentialAssertionRequest(challenge: challenge)
        request.userVerificationPreference = .preferred
        guard case let .assertion(id, clientData, authData, signature, userID) = try await perform(request) else {
            throw SecurityKeyError.noCredential
        }
        return KeyAssertion(credentialID: id, rawClientDataJSON: clientData, rawAuthenticatorData: authData,
                            signature: signature, userID: userID, challenge: challenge)
    }

    private func perform(_ request: ASAuthorizationRequest) async throws -> RawCredential {
        // Only one key request at a time: end any earlier one instead of leaking it.
        finish(.failure(SecurityKeyError.cancelled))
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.controller = controller
            controller.performRequests()
        }
    }

    private func finish(_ result: Result<RawCredential, Error>) {
        guard let cont = continuation else { return }
        continuation = nil
        controller = nil
        cont.resume(with: result)
    }

    private static func randomChallenge() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            // SystemRandomNumberGenerator is also cryptographically secure on Apple platforms.
            bytes = (0..<32).map { _ in UInt8.random(in: 0...255) }
        }
        return Data(bytes)
    }

    /// Reads a property as optional whether the SDK declares it `Data` or `Data?`,
    /// so a missing field fails the check instead of crashing.
    private static func optional(_ data: Data?) -> Data? { data }
}

extension SecurityKeyService: ASAuthorizationControllerDelegate {
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let reg = authorization.credential as? ASAuthorizationSecurityKeyPublicKeyCredentialRegistration {
            finish(.success(.registration(
                credentialID: reg.credentialID,
                clientDataJSON: reg.rawClientDataJSON,
                attestationObject: Self.optional(reg.rawAttestationObject)
            )))
        } else if let assertion = authorization.credential as? ASAuthorizationSecurityKeyPublicKeyCredentialAssertion {
            // Empty data fails verification (malformed authenticatorData / bad signature).
            finish(.success(.assertion(
                credentialID: assertion.credentialID,
                clientDataJSON: assertion.rawClientDataJSON,
                authenticatorData: Self.optional(assertion.rawAuthenticatorData) ?? Data(),
                signature: Self.optional(assertion.signature) ?? Data(),
                userID: Self.optional(assertion.userID) ?? Data()
            )))
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
