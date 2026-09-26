// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  WebAuthnVerifier.swift
//  Pawl: domain core
//
//  Pure checks on what a FIDO2 security key sends back. No UI and no AuthenticationServices
//  here, so every rule is covered by PawlTests/WebAuthnVerifierTests.swift with synthetic data.
//
//  What 2.1 verifies, on the phone, for every key tap:
//    1. clientDataJSON: `type` is right and `challenge` is byte-equal to the one we just issued
//       (so an old response can't be replayed).
//    2. authenticatorData: rpIdHash == SHA-256(PawlConfig.relyingPartyID), the User Present flag
//       is set, and the signature counter never goes backwards (clone detection; skipped only
//       when the stored and received counters are both 0, per WebAuthn §6.1.1).
//    3. The ES256 signature over authenticatorData || SHA-256(clientDataJSON), using the public
//       key captured from the attestation object when the key was paired.
//
//  What it does NOT verify (residual gaps, also listed in README.md and SECURITY.md):
//    - Keys paired on 2.0 or earlier were stored without their public key, and a public key
//      cannot be recovered from an assertion. For those keys, step 3 is skipped until the key
//      is re-paired. Steps 1 and 2 still apply.
//    - Attestation is not checked, so this does not prove the key is genuine hardware from a
//      particular maker. It proves the same key that was paired produced this signature.
//    - All of this runs on the phone. On a jailbroken phone the owner controls the code and the
//      stored key, so no on-device check can hold.
//

import Foundation
import CryptoKit

// MARK: - Stored key

/// A paired security key, as Pawl stores it on the phone.
nonisolated public struct RegisteredKey: Codable, Equatable, Sendable {
    public var credentialID: Data
    /// Uncompressed P-256 public key (0x04 || X || Y). nil for keys paired before 2.1.
    public var publicKey: Data?
    /// Last signature counter seen from this key.
    public var signCount: UInt32

    public init(credentialID: Data, publicKey: Data?, signCount: UInt32) {
        self.credentialID = credentialID
        self.publicKey = publicKey
        self.signCount = signCount
    }
}

// MARK: - Errors

nonisolated public enum WebAuthnError: Error, Equatable, Sendable {
    case malformedClientData
    case wrongType(String)
    case challengeMismatch
    case malformedAuthenticatorData
    case malformedCBOR
    case malformedAttestationObject
    case wrongRelyingParty
    case userNotPresent
    case counterWentBackwards(stored: UInt32, received: UInt32)
    case missingAttestedCredential
    case credentialMismatch
    case unsupportedPublicKey
    case badSignature
}

// MARK: - Verifier

nonisolated public enum WebAuthnVerifier {

    public static func rpIdHash(_ relyingPartyID: String) -> Data {
        Data(SHA256.hash(data: Data(relyingPartyID.utf8)))
    }

    /// Check a new key's registration and capture its public key.
    public static func verifyRegistration(credentialID: Data,
                                          clientDataJSON: Data,
                                          attestationObject: Data,
                                          challenge: Data,
                                          relyingPartyID: String) throws -> RegisteredKey {
        try ClientData.verify(clientDataJSON, type: "webauthn.create", challenge: challenge)

        var reader = CBORReader([UInt8](attestationObject))
        guard case .map(let pairs) = try reader.read(),
              case .bytes(let authBytes)? = pairs.first(where: { $0.key == .text("authData") })?.value
        else { throw WebAuthnError.malformedAttestationObject }

        let auth = try AuthenticatorData(authBytes)
        try checkRelyingPartyAndPresence(auth, relyingPartyID)
        guard let attestedID = auth.credentialID, let publicKey = auth.publicKey else {
            throw WebAuthnError.missingAttestedCredential
        }
        guard attestedID == credentialID else { throw WebAuthnError.credentialMismatch }
        return RegisteredKey(credentialID: credentialID, publicKey: publicKey, signCount: auth.signCount)
    }

    /// Check one key tap against the paired key. Returns the key with its counter advanced;
    /// the caller must store it. Throws on any failed check. Never weaker than 2.0: the
    /// credential ID must still match.
    public static func verifyAssertion(credentialID: Data,
                                       clientDataJSON: Data,
                                       authenticatorData: Data,
                                       signature: Data,
                                       challenge: Data,
                                       relyingPartyID: String,
                                       registered: RegisteredKey) throws -> RegisteredKey {
        guard credentialID == registered.credentialID else { throw WebAuthnError.credentialMismatch }
        try ClientData.verify(clientDataJSON, type: "webauthn.get", challenge: challenge)

        let auth = try AuthenticatorData(authenticatorData)
        try checkRelyingPartyAndPresence(auth, relyingPartyID)

        if let publicKeyData = registered.publicKey {
            let publicKey: P256.Signing.PublicKey
            do { publicKey = try P256.Signing.PublicKey(x963Representation: publicKeyData) }
            catch { throw WebAuthnError.unsupportedPublicKey }
            guard let sig = try? P256.Signing.ECDSASignature(derRepresentation: signature) else {
                throw WebAuthnError.badSignature
            }
            let signed = authenticatorData + Data(SHA256.hash(data: clientDataJSON))
            guard publicKey.isValidSignature(sig, for: signed) else { throw WebAuthnError.badSignature }
        }
        // else: a key paired before 2.1 has no stored public key. See the header comment.

        if !(registered.signCount == 0 && auth.signCount == 0) {
            guard auth.signCount > registered.signCount else {
                throw WebAuthnError.counterWentBackwards(stored: registered.signCount, received: auth.signCount)
            }
        }

        var updated = registered
        updated.signCount = auth.signCount
        return updated
    }

    static func checkRelyingPartyAndPresence(_ auth: AuthenticatorData, _ relyingPartyID: String) throws {
        guard auth.rpIdHash == rpIdHash(relyingPartyID) else { throw WebAuthnError.wrongRelyingParty }
        guard auth.flags & AuthenticatorData.userPresent != 0 else { throw WebAuthnError.userNotPresent }
    }
}

// MARK: - clientDataJSON

nonisolated enum ClientData {
    static func verify(_ json: Data, type expectedType: String, challenge: Data) throws {
        guard let object = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let type = object["type"] as? String,
              let encodedChallenge = object["challenge"] as? String
        else { throw WebAuthnError.malformedClientData }
        guard type == expectedType else { throw WebAuthnError.wrongType(type) }
        guard let received = base64URLDecode(encodedChallenge), received == challenge else {
            throw WebAuthnError.challengeMismatch
        }
    }

    static func base64URLDecode(_ string: String) -> Data? {
        var s = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        return Data(base64Encoded: s)
    }
}

// MARK: - authenticatorData (WebAuthn §6.1)

nonisolated struct AuthenticatorData: Equatable {
    static let userPresent: UInt8 = 0x01
    static let attestedCredentialIncluded: UInt8 = 0x40

    let rpIdHash: Data
    let flags: UInt8
    let signCount: UInt32
    /// Present only when the AT flag is set (registration).
    let credentialID: Data?
    /// Uncompressed P-256 key (0x04 || X || Y), present only when the AT flag is set.
    let publicKey: Data?

    init(_ raw: Data) throws {
        let b = [UInt8](raw)
        guard b.count >= 37 else { throw WebAuthnError.malformedAuthenticatorData }
        rpIdHash = Data(b[0..<32])
        flags = b[32]
        signCount = UInt32(b[33]) << 24 | UInt32(b[34]) << 16 | UInt32(b[35]) << 8 | UInt32(b[36])

        guard flags & Self.attestedCredentialIncluded != 0 else {
            credentialID = nil
            publicKey = nil
            return
        }
        // aaguid (16) | credentialIdLength (2, big endian) | credentialId | COSE_Key (CBOR)
        var i = 37 + 16
        guard b.count >= i + 2 else { throw WebAuthnError.malformedAuthenticatorData }
        let length = Int(b[i]) << 8 | Int(b[i + 1])
        i += 2
        guard b.count >= i + length else { throw WebAuthnError.malformedAuthenticatorData }
        credentialID = Data(b[i..<(i + length)])
        i += length
        var reader = CBORReader(b, at: i)
        publicKey = try Self.p256PublicKey(fromCOSE: try reader.read())
    }

    /// COSE_Key for ES256: kty(1)=EC2(2), alg(3)=ES256(-7), crv(-1)=P-256(1), x(-2), y(-3).
    static func p256PublicKey(fromCOSE value: CBOR) throws -> Data {
        guard case .map(let pairs) = value else { throw WebAuthnError.unsupportedPublicKey }
        func field(_ label: Int64) -> CBOR? { pairs.first(where: { $0.key == .int(label) })?.value }
        guard field(1) == .int(2), field(3) == .int(-7), field(-1) == .int(1),
              case .bytes(let x)? = field(-2), case .bytes(let y)? = field(-3),
              x.count == 32, y.count == 32
        else { throw WebAuthnError.unsupportedPublicKey }
        return Data([0x04]) + x + y
    }
}

// MARK: - Minimal CBOR reader (RFC 8949), only what WebAuthn needs

nonisolated struct CBORPair: Equatable {
    let key: CBOR
    let value: CBOR
}

nonisolated enum CBOR: Equatable {
    case int(Int64)
    case bytes(Data)
    case text(String)
    case array([CBOR])
    case map([CBORPair])
    case simple(UInt8)
}

nonisolated struct CBORReader {
    private let bytes: [UInt8]
    private(set) var offset: Int
    private static let maxDepth = 8

    init(_ bytes: [UInt8], at offset: Int = 0) {
        self.bytes = bytes
        self.offset = offset
    }

    mutating func read() throws -> CBOR { try read(depth: 0) }

    private mutating func read(depth: Int) throws -> CBOR {
        guard depth < Self.maxDepth else { throw WebAuthnError.malformedCBOR }
        let initial = try nextByte()
        let major = initial >> 5
        let info = initial & 0x1f
        let argument = try readArgument(info)

        switch major {
        case 0:
            guard argument <= UInt64(Int64.max) else { throw WebAuthnError.malformedCBOR }
            return .int(Int64(argument))
        case 1:
            guard argument <= UInt64(Int64.max) else { throw WebAuthnError.malformedCBOR }
            return .int(-1 - Int64(argument))
        case 2:
            return .bytes(Data(try take(argument)))
        case 3:
            guard let text = String(bytes: try take(argument), encoding: .utf8) else {
                throw WebAuthnError.malformedCBOR
            }
            return .text(text)
        case 4:
            guard argument <= UInt64(bytes.count - offset) else { throw WebAuthnError.malformedCBOR }
            var items: [CBOR] = []
            for _ in 0..<Int(argument) { items.append(try read(depth: depth + 1)) }
            return .array(items)
        case 5:
            guard argument <= UInt64(bytes.count - offset) else { throw WebAuthnError.malformedCBOR }
            var pairs: [CBORPair] = []
            for _ in 0..<Int(argument) {
                let key = try read(depth: depth + 1)
                let value = try read(depth: depth + 1)
                pairs.append(CBORPair(key: key, value: value))
            }
            return .map(pairs)
        case 7:
            // Only simple values (false, true, null, undefined). Floats are never used here.
            guard info < 24 else { throw WebAuthnError.malformedCBOR }
            return .simple(UInt8(argument))
        default:
            // Major type 6 (tags) is not used by WebAuthn attestation or COSE keys.
            throw WebAuthnError.malformedCBOR
        }
    }

    private mutating func nextByte() throws -> UInt8 {
        guard offset < bytes.count else { throw WebAuthnError.malformedCBOR }
        defer { offset += 1 }
        return bytes[offset]
    }

    private mutating func readArgument(_ info: UInt8) throws -> UInt64 {
        switch info {
        case 0..<24: return UInt64(info)
        case 24: return UInt64(try nextByte())
        case 25: return try readBigEndian(2)
        case 26: return try readBigEndian(4)
        case 27: return try readBigEndian(8)
        default: throw WebAuthnError.malformedCBOR     // 28-30 reserved, 31 indefinite length
        }
    }

    private mutating func readBigEndian(_ count: Int) throws -> UInt64 {
        var value: UInt64 = 0
        for _ in 0..<count { value = value << 8 | UInt64(try nextByte()) }
        return value
    }

    private mutating func take(_ count: UInt64) throws -> [UInt8] {
        guard count <= UInt64(bytes.count - offset) else { throw WebAuthnError.malformedCBOR }
        let n = Int(count)
        defer { offset += n }
        return Array(bytes[offset..<(offset + n)])
    }
}
