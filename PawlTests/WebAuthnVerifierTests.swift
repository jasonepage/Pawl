// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  WebAuthnVerifierTests.swift
//  PawlTests: domain core
//
//  Executable spec for the 2.1 security key checks. Every fixture is synthetic: a P-256 key
//  made in the test plays the part of the security key, and authenticatorData, clientDataJSON
//  and the attestation object are built byte by byte. No device or real key needed.
//

import XCTest
import CryptoKit
@testable import Pawl

final class WebAuthnVerifierTests: XCTestCase {

    private let rpID = "getpawl.com"
    private let challenge = Data((0..<32).map { UInt8($0) })
    private let credentialID = Data((0..<16).map { UInt8(0xA0 + $0) })
    private let signer = P256.Signing.PrivateKey()

    // MARK: - Fixture builders

    private func b64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func clientData(type: String = "webauthn.get", challenge: Data? = nil) -> Data {
        let c = b64url(challenge ?? self.challenge)
        return Data(#"{"type":"\#(type)","challenge":"\#(c)","origin":"https://getpawl.com"}"#.utf8)
    }

    private func authData(rpID: String? = nil, flags: UInt8 = 0x01, counter: UInt32,
                          attested: (id: Data, cose: Data)? = nil) -> Data {
        var d = Data(SHA256.hash(data: Data((rpID ?? self.rpID).utf8)))
        d.append(attested == nil ? flags : flags | 0x40)
        d.append(contentsOf: [UInt8(counter >> 24 & 0xff), UInt8(counter >> 16 & 0xff),
                              UInt8(counter >> 8 & 0xff), UInt8(counter & 0xff)])
        if let attested {
            d.append(Data(repeating: 0, count: 16))                          // aaguid
            d.append(contentsOf: [UInt8(attested.id.count >> 8), UInt8(attested.id.count & 0xff)])
            d.append(attested.id)
            d.append(attested.cose)
        }
        return d
    }

    private func cborBytesHeader(_ count: Int) -> Data {
        if count < 24 { return Data([0x40 | UInt8(count)]) }
        if count < 256 { return Data([0x58, UInt8(count)]) }
        return Data([0x59, UInt8(count >> 8), UInt8(count & 0xff)])
    }

    private func cborText(_ s: String) -> Data {
        let utf8 = Data(s.utf8)
        return Data([0x60 | UInt8(utf8.count)]) + utf8                        // short strings only
    }

    /// COSE_Key {1: 2, 3: -7, -1: 1, -2: x, -3: y}
    private func coseKey(for key: P256.Signing.PublicKey) -> Data {
        let raw = key.x963Representation                                    // 0x04 || X || Y
        let x = raw.subdata(in: 1..<33), y = raw.subdata(in: 33..<65)
        var d = Data([0xA5, 0x01, 0x02, 0x03, 0x26, 0x20, 0x01])
        d.append(0x21); d.append(cborBytesHeader(32)); d.append(x)
        d.append(0x22); d.append(cborBytesHeader(32)); d.append(y)
        return d
    }

    /// {"fmt": "none", "attStmt": {}, "authData": bytes}
    private func attestationObject(authData: Data) -> Data {
        var d = Data([0xA3])
        d.append(cborText("fmt")); d.append(cborText("none"))
        d.append(cborText("attStmt")); d.append(Data([0xA0]))
        d.append(cborText("authData")); d.append(cborBytesHeader(authData.count)); d.append(authData)
        return d
    }

    private func sign(_ authData: Data, _ clientData: Data, with key: P256.Signing.PrivateKey? = nil) throws -> Data {
        let message = authData + Data(SHA256.hash(data: clientData))
        return try (key ?? signer).signature(for: message).derRepresentation
    }

    private var registered: RegisteredKey {
        RegisteredKey(credentialID: credentialID, publicKey: signer.publicKey.x963Representation, signCount: 5)
    }

    private func assertion(authData a: Data, clientData c: Data, signature s: Data? = nil,
                           credentialID id: Data? = nil, registered r: RegisteredKey? = nil) throws -> RegisteredKey {
        try WebAuthnVerifier.verifyAssertion(
            credentialID: id ?? credentialID, clientDataJSON: c, authenticatorData: a,
            signature: try s ?? sign(a, c), challenge: challenge, relyingPartyID: rpID,
            registered: r ?? registered)
    }

    private func assertRejects(_ expected: WebAuthnError, file: StaticString = #filePath, line: UInt = #line,
                               _ body: () throws -> Void) {
        XCTAssertThrowsError(try body(), file: file, line: line) { error in
            XCTAssertEqual(error as? WebAuthnError, expected, file: file, line: line)
        }
    }

    // MARK: - Assertion: the happy path

    func test_validAssertion_passes_andAdvancesCounter() throws {
        let updated = try assertion(authData: authData(counter: 6), clientData: clientData())
        XCTAssertEqual(updated.signCount, 6)
        XCTAssertEqual(updated.credentialID, credentialID)
        XCTAssertEqual(updated.publicKey, registered.publicKey)
    }

    // MARK: - Assertion: each check rejects on its own

    func test_differentCredentialID_isRejected() {
        assertRejects(.credentialMismatch) {
            _ = try assertion(authData: authData(counter: 6), clientData: clientData(), credentialID: Data([1, 2, 3]))
        }
    }

    func test_challengeMismatch_isRejected() {
        let c = clientData(challenge: Data(repeating: 9, count: 32))
        assertRejects(.challengeMismatch) { _ = try assertion(authData: authData(counter: 6), clientData: c) }
    }

    func test_replayedResponse_isRejected() throws {
        // A response signed for an earlier challenge is valid on its own, but not for this one.
        let old = clientData(challenge: Data(repeating: 7, count: 32))
        let a = authData(counter: 6)
        let sig = try sign(a, old)
        assertRejects(.challengeMismatch) { _ = try assertion(authData: a, clientData: old, signature: sig) }
    }

    func test_registrationTypeUsedForUnlock_isRejected() {
        assertRejects(.wrongType("webauthn.create")) {
            _ = try assertion(authData: authData(counter: 6), clientData: clientData(type: "webauthn.create"))
        }
    }

    func test_wrongRpIdHash_isRejected() {
        assertRejects(.wrongRelyingParty) {
            _ = try assertion(authData: authData(rpID: "evil.example", counter: 6), clientData: clientData())
        }
    }

    func test_missingUserPresentFlag_isRejected() {
        assertRejects(.userNotPresent) {
            _ = try assertion(authData: authData(flags: 0x00, counter: 6), clientData: clientData())
        }
    }

    func test_counterRollback_isRejected() {
        assertRejects(.counterWentBackwards(stored: 5, received: 4)) {
            _ = try assertion(authData: authData(counter: 4), clientData: clientData())
        }
    }

    func test_counterRepeat_isRejected() {
        assertRejects(.counterWentBackwards(stored: 5, received: 5)) {
            _ = try assertion(authData: authData(counter: 5), clientData: clientData())
        }
    }

    func test_counterDropsToZero_isRejected() {
        assertRejects(.counterWentBackwards(stored: 5, received: 0)) {
            _ = try assertion(authData: authData(counter: 0), clientData: clientData())
        }
    }

    func test_bothCountersZero_isAllowed() throws {
        // Some authenticators never count. WebAuthn says skip the check when both are 0.
        var r = registered; r.signCount = 0
        let updated = try assertion(authData: authData(counter: 0), clientData: clientData(), registered: r)
        XCTAssertEqual(updated.signCount, 0)
    }

    func test_signatureFromAnotherKey_isRejected() throws {
        let a = authData(counter: 6), c = clientData()
        let sig = try sign(a, c, with: P256.Signing.PrivateKey())
        assertRejects(.badSignature) { _ = try assertion(authData: a, clientData: c, signature: sig) }
    }

    func test_authDataChangedAfterSigning_isRejected() throws {
        let c = clientData()
        let sig = try sign(authData(counter: 6), c)
        assertRejects(.badSignature) { _ = try assertion(authData: authData(counter: 99), clientData: c, signature: sig) }
    }

    func test_garbageSignature_isRejected() {
        assertRejects(.badSignature) {
            _ = try assertion(authData: authData(counter: 6), clientData: clientData(), signature: Data([0x30, 0x00]))
        }
    }

    func test_emptyAuthenticatorData_isRejected() {
        assertRejects(.malformedAuthenticatorData) {
            _ = try assertion(authData: Data(), clientData: clientData(), signature: Data())
        }
    }

    // MARK: - Keys paired before 2.1 (no public key)

    func test_legacyKey_skipsSignature_butStillChecksEverythingElse() throws {
        let legacy = RegisteredKey(credentialID: credentialID, publicKey: nil, signCount: 0)
        let ok = try assertion(authData: authData(counter: 3), clientData: clientData(),
                               signature: Data(), registered: legacy)
        XCTAssertEqual(ok.signCount, 3)
        assertRejects(.challengeMismatch) {
            _ = try assertion(authData: authData(counter: 3), clientData: clientData(challenge: Data([1])),
                              signature: Data(), registered: legacy)
        }
        assertRejects(.wrongRelyingParty) {
            _ = try assertion(authData: authData(rpID: "evil.example", counter: 3), clientData: clientData(),
                              signature: Data(), registered: legacy)
        }
    }

    // MARK: - Registration

    private func registration(authData a: Data, clientData c: Data? = nil, credentialID id: Data? = nil) throws -> RegisteredKey {
        try WebAuthnVerifier.verifyRegistration(
            credentialID: id ?? credentialID,
            clientDataJSON: c ?? clientData(type: "webauthn.create"),
            attestationObject: attestationObject(authData: a),
            challenge: challenge, relyingPartyID: rpID)
    }

    func test_registration_capturesPublicKeyAndCounter() throws {
        let a = authData(counter: 2, attested: (credentialID, coseKey(for: signer.publicKey)))
        let key = try registration(authData: a)
        XCTAssertEqual(key.credentialID, credentialID)
        XCTAssertEqual(key.publicKey, signer.publicKey.x963Representation)
        XCTAssertEqual(key.signCount, 2)
    }

    func test_registration_thenAssertion_roundTrip() throws {
        let a = authData(counter: 2, attested: (credentialID, coseKey(for: signer.publicKey)))
        let key = try registration(authData: a)
        let updated = try assertion(authData: authData(counter: 3), clientData: clientData(), registered: key)
        XCTAssertEqual(updated.signCount, 3)
    }

    func test_registration_challengeMismatch_isRejected() {
        let a = authData(counter: 0, attested: (credentialID, coseKey(for: signer.publicKey)))
        assertRejects(.challengeMismatch) {
            _ = try registration(authData: a, clientData: clientData(type: "webauthn.create", challenge: Data([4])))
        }
    }

    func test_registration_assertionTypeUsed_isRejected() {
        let a = authData(counter: 0, attested: (credentialID, coseKey(for: signer.publicKey)))
        assertRejects(.wrongType("webauthn.get")) { _ = try registration(authData: a, clientData: clientData()) }
    }

    func test_registration_credentialIDDiffersFromAttested_isRejected() {
        let a = authData(counter: 0, attested: (credentialID, coseKey(for: signer.publicKey)))
        assertRejects(.credentialMismatch) { _ = try registration(authData: a, credentialID: Data([9, 9])) }
    }

    func test_registration_wrongRpIdHash_isRejected() {
        let a = authData(rpID: "evil.example", counter: 0, attested: (credentialID, coseKey(for: signer.publicKey)))
        assertRejects(.wrongRelyingParty) { _ = try registration(authData: a) }
    }

    func test_registration_withoutAttestedCredential_isRejected() {
        assertRejects(.missingAttestedCredential) { _ = try registration(authData: authData(counter: 0)) }
    }

    func test_registration_nonES256Key_isRejected() {
        // Same shape, but alg = -8 (EdDSA) instead of -7.
        var cose = coseKey(for: signer.publicKey)
        cose[4] = 0x27
        let a = authData(counter: 0, attested: (credentialID, cose))
        assertRejects(.unsupportedPublicKey) { _ = try registration(authData: a) }
    }

    func test_registration_truncatedCOSEKey_isRejected() {
        let cose = coseKey(for: signer.publicKey).prefix(20)
        let a = authData(counter: 0, attested: (credentialID, Data(cose)))
        assertRejects(.malformedCBOR) { _ = try registration(authData: a) }
    }

    // MARK: - Small parsers

    func test_base64URL_decodesWithoutPadding() {
        XCTAssertEqual(ClientData.base64URLDecode(b64url(Data([0xfb, 0xff, 0xfe]))), Data([0xfb, 0xff, 0xfe]))
        XCTAssertEqual(ClientData.base64URLDecode(b64url(Data([0x01]))), Data([0x01]))
    }

    func test_cbor_rejectsIndefiniteLength() {
        var reader = CBORReader([0x5F, 0x41, 0x00, 0xFF])
        XCTAssertThrowsError(try reader.read())
    }

    func test_cbor_rejectsLengthPastEnd() {
        var reader = CBORReader([0x58, 0xFF, 0x00])
        XCTAssertThrowsError(try reader.read())
    }
}
