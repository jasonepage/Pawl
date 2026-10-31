// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  AllyDecisionVerifier.swift
//  Pawl: domain core (2.5, docs/18 section 4.3)
//
//  How the owner's phone knows a "yes" really came from the ally.
//
//  The owner can write anything into their own iCloud zone, so a Decision record alone proves
//  nothing. At pairing the ally's phone makes a P-256 signing key in its Secure Enclave and
//  hands the public half to the owner, who keeps a copy in the Keychain. Every decision is
//  signed with the private half over a fixed message:
//
//      "pawl-ally-decision-v1" || request id (16 bytes) || nonce || approved (1 byte) || expiry
//
//  The owner's phone rebuilds that message from the request it has open, checks the signature
//  against its saved copy of the public key, and only then treats the answer as real. Same idea
//  as WebAuthnVerifier: verify against a key saved when you paired.
//
//  Pure Swift and CryptoKit, no iCloud and no UI, so PawlTests/AllyDecisionVerifierTests.swift
//  covers every rule with made-up keys. What this cannot stop is the same list as the key
//  check: a jailbroken phone, or a Debug build the owner made themselves.
//

import Foundation
import CryptoKit

// MARK: - Records (the shapes that go into iCloud; CloudKit mapping is step 2)

/// What the person is asking for. The ally sees only this and the asker's name (D5).
nonisolated public enum AllyRequestKind: String, Codable, Sendable {
    case unlock          // start the cooling-off, same as a key tap
    case blockLess       // remove an app, turn off a category, loosen a set
}

/// One open request. Written by the owner, deleted as soon as it is answered or expires.
nonisolated public struct AllyRequest: Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: AllyRequestKind
    public var createdAt: Date
    public var expiresAt: Date
    /// 32 random bytes made for this request. Binds the signature to this request only.
    public var nonce: Data

    public init(id: UUID = UUID(), kind: AllyRequestKind, createdAt: Date, expiresAt: Date, nonce: Data) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.nonce = nonce
    }

    /// A fresh request with a random nonce, open for the standard window.
    public static func make(kind: AllyRequestKind, now: Date, window: TimeInterval = UnlockMachine.allyRequestWindow) -> AllyRequest {
        var bytes = [UInt8](repeating: 0, count: 32)
        for i in bytes.indices { bytes[i] = UInt8.random(in: .min ... .max) }
        return AllyRequest(kind: kind, createdAt: now, expiresAt: now.addingTimeInterval(window), nonce: Data(bytes))
    }
}

/// The ally's answer. Written by the ally, deleted by the owner once read.
nonisolated public struct AllyDecision: Codable, Equatable, Sendable {
    public var requestID: UUID
    public var approved: Bool
    public var signedAt: Date
    /// ES256 signature, raw 64 byte form (r || s), over `AllyDecisionVerifier.message(...)`.
    public var signature: Data

    public init(requestID: UUID, approved: Bool, signedAt: Date, signature: Data) {
        self.requestID = requestID
        self.approved = approved
        self.signedAt = signedAt
        self.signature = signature
    }
}

// MARK: - Errors

nonisolated public enum AllyDecisionError: Error, Equatable, Sendable {
    case wrongRequest            // the decision names a request that is not the open one
    case expired                 // answered after the request's expiry
    case unsupportedPublicKey    // the saved public key is not a P-256 key
    case malformedSignature
    case badSignature            // the signature does not match the saved public key
}

// MARK: - Verifier

nonisolated public enum AllyDecisionVerifier {

    /// Fixed label at the front of every signed message (docs/18 section 4.3 point 7), so a
    /// signature made for this purpose can never be reused for anything else.
    public static let label = "pawl-ally-decision-v1"

    /// The exact bytes both phones sign and check. Any change here is a new version label.
    public static func message(requestID: UUID, nonce: Data, approved: Bool, expiresAt: Date) -> Data {
        var m = Data(label.utf8)
        m.append(uuidBytes(requestID))
        m.append(nonce)
        m.append(approved ? 1 : 0)
        var seconds = Int64(expiresAt.timeIntervalSince1970).bigEndian
        withUnsafeBytes(of: &seconds) { m.append(contentsOf: $0) }
        return m
    }

    /// Check one decision against the request the owner has open and the ally's saved public
    /// key. Returns whether the ally approved. Throws when the decision cannot be trusted.
    /// A thrown error and a returned `false` both mean "nothing changes".
    ///
    /// Replay: this function has no memory. One request is used once because the caller
    /// (UnlockMachine, via `withdrawAllyRequest`) deletes the request on the first accepted
    /// decision, after which the same decision no longer names an open request.
    public static func verify(_ decision: AllyDecision,
                              against request: AllyRequest,
                              allyPublicKey: Data,
                              now: Date) throws -> Bool {
        guard decision.requestID == request.id else { throw AllyDecisionError.wrongRequest }
        guard now <= request.expiresAt, decision.signedAt <= request.expiresAt else {
            throw AllyDecisionError.expired
        }
        let publicKey: P256.Signing.PublicKey
        do { publicKey = try P256.Signing.PublicKey(x963Representation: allyPublicKey) }
        catch { throw AllyDecisionError.unsupportedPublicKey }
        guard let sig = try? P256.Signing.ECDSASignature(rawRepresentation: decision.signature) else {
            throw AllyDecisionError.malformedSignature
        }
        let signed = message(requestID: request.id, nonce: request.nonce,
                             approved: decision.approved, expiresAt: request.expiresAt)
        guard publicKey.isValidSignature(sig, for: signed) else { throw AllyDecisionError.badSignature }
        return decision.approved
    }

    /// The ally's side: build a signed decision. `sign` is whatever makes the signature, so
    /// the app can pass a Secure Enclave key and the tests can pass a plain P-256 key.
    public static func makeDecision(for request: AllyRequest,
                                    approved: Bool,
                                    now: Date,
                                    sign: (Data) throws -> P256.Signing.ECDSASignature) rethrows -> AllyDecision {
        let signed = message(requestID: request.id, nonce: request.nonce,
                             approved: approved, expiresAt: request.expiresAt)
        let sig = try sign(signed)
        return AllyDecision(requestID: request.id, approved: approved, signedAt: now, signature: sig.rawRepresentation)
    }

    static func uuidBytes(_ id: UUID) -> Data {
        let u = id.uuid
        return Data([u.0, u.1, u.2, u.3, u.4, u.5, u.6, u.7, u.8, u.9, u.10, u.11, u.12, u.13, u.14, u.15])
    }
}
