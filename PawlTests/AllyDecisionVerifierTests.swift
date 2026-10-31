// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  AllyDecisionVerifierTests.swift
//  PawlTests: domain core
//
//  2.5 ally approvals, step 1 of docs/18. Made-up keys play the ally's Secure Enclave key.
//  Cases the plan asks for: good yes, good no, wrong key, wrong nonce, expired, replayed.
//

import XCTest
import CryptoKit
@testable import Pawl

final class AllyDecisionVerifierTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_000_000)
    private let ally = P256.Signing.PrivateKey()
    private var allyPublic: Data { ally.publicKey.x963Representation }

    private func request(now: Date? = nil) -> AllyRequest {
        AllyRequest.make(kind: .unlock, now: now ?? t0)
    }

    private func decision(_ approved: Bool, for request: AllyRequest, key: P256.Signing.PrivateKey? = nil, at: Date? = nil) -> AllyDecision {
        let k = key ?? ally
        return try! AllyDecisionVerifier.makeDecision(for: request, approved: approved, now: at ?? t0.addingTimeInterval(60)) {
            try k.signature(for: $0)
        }
    }

    // Good yes.
    func test_goodYes_verifies() throws {
        let r = request()
        let ok = try AllyDecisionVerifier.verify(decision(true, for: r), against: r, allyPublicKey: allyPublic, now: t0.addingTimeInterval(120))
        XCTAssertTrue(ok)
    }

    // Good no: the signature is fine and the answer is no.
    func test_goodNo_verifiesAsFalse() throws {
        let r = request()
        let ok = try AllyDecisionVerifier.verify(decision(false, for: r), against: r, allyPublicKey: allyPublic, now: t0.addingTimeInterval(120))
        XCTAssertFalse(ok)
    }

    // The owner cannot flip a signed no into a yes: `approved` is inside the signed message.
    func test_flippedAnswer_badSignature() {
        let r = request()
        var d = decision(false, for: r)
        d.approved = true
        XCTAssertThrowsError(try AllyDecisionVerifier.verify(d, against: r, allyPublicKey: allyPublic, now: t0)) {
            XCTAssertEqual($0 as? AllyDecisionError, .badSignature)
        }
    }

    // Wrong key: a yes signed by anyone but the paired ally is rejected.
    func test_wrongKey_badSignature() {
        let r = request()
        let stranger = P256.Signing.PrivateKey()
        let d = decision(true, for: r, key: stranger)
        XCTAssertThrowsError(try AllyDecisionVerifier.verify(d, against: r, allyPublicKey: allyPublic, now: t0)) {
            XCTAssertEqual($0 as? AllyDecisionError, .badSignature)
        }
    }

    // Wrong nonce: a yes signed for a request with a different nonce does not carry over,
    // even with the same request id.
    func test_wrongNonce_badSignature() {
        let r = request()
        var other = r
        other.nonce = Data(repeating: 7, count: 32)
        let d = decision(true, for: other)
        XCTAssertThrowsError(try AllyDecisionVerifier.verify(d, against: r, allyPublicKey: allyPublic, now: t0)) {
            XCTAssertEqual($0 as? AllyDecisionError, .badSignature)
        }
    }

    // Wrong request: a decision naming some other request id is refused before any crypto.
    func test_wrongRequestID_refused() {
        let r = request()
        var d = decision(true, for: r)
        d.requestID = UUID()
        XCTAssertThrowsError(try AllyDecisionVerifier.verify(d, against: r, allyPublicKey: allyPublic, now: t0)) {
            XCTAssertEqual($0 as? AllyDecisionError, .wrongRequest)
        }
    }

    // Expired: a good yes that arrives after the 30 minutes is refused.
    func test_expired_refused() {
        let r = request()
        let d = decision(true, for: r)
        let late = r.expiresAt.addingTimeInterval(1)
        XCTAssertThrowsError(try AllyDecisionVerifier.verify(d, against: r, allyPublicKey: allyPublic, now: late)) {
            XCTAssertEqual($0 as? AllyDecisionError, .expired)
        }
    }

    // Expired: a decision the ally signed after expiry is refused even if read in time.
    func test_signedLate_refused() {
        let r = request()
        let d = decision(true, for: r, at: r.expiresAt.addingTimeInterval(5))
        XCTAssertThrowsError(try AllyDecisionVerifier.verify(d, against: r, allyPublicKey: allyPublic, now: t0)) {
            XCTAssertEqual($0 as? AllyDecisionError, .expired)
        }
    }

    // The owner cannot stretch the window: expiry is inside the signed message.
    func test_stretchedExpiry_badSignature() {
        let r = request()
        let d = decision(true, for: r)
        var stretched = r
        stretched.expiresAt = r.expiresAt.addingTimeInterval(3600)
        XCTAssertThrowsError(try AllyDecisionVerifier.verify(d, against: stretched, allyPublicKey: allyPublic, now: r.expiresAt.addingTimeInterval(60))) {
            XCTAssertEqual($0 as? AllyDecisionError, .badSignature)
        }
    }

    // Replayed: a yes used once cannot be used for the next request. The next request has a
    // new id and nonce, so the old signature names a request that is not open.
    func test_replayedYes_refusedForNextRequest() throws {
        let first = request()
        let d = decision(true, for: first)
        XCTAssertTrue(try AllyDecisionVerifier.verify(d, against: first, allyPublicKey: allyPublic, now: t0))
        let next = request(now: t0.addingTimeInterval(600))
        XCTAssertThrowsError(try AllyDecisionVerifier.verify(d, against: next, allyPublicKey: allyPublic, now: t0.addingTimeInterval(700))) {
            XCTAssertEqual($0 as? AllyDecisionError, .wrongRequest)
        }
    }

    // Garbage where the signature should be is refused, not crashed on.
    func test_malformedSignature_refused() {
        let r = request()
        var d = decision(true, for: r)
        d.signature = Data([1, 2, 3])
        XCTAssertThrowsError(try AllyDecisionVerifier.verify(d, against: r, allyPublicKey: allyPublic, now: t0)) {
            XCTAssertEqual($0 as? AllyDecisionError, .malformedSignature)
        }
    }

    // A saved public key that is not P-256 is refused.
    func test_badPublicKey_refused() {
        let r = request()
        let d = decision(true, for: r)
        XCTAssertThrowsError(try AllyDecisionVerifier.verify(d, against: r, allyPublicKey: Data([0x04, 0x01]), now: t0)) {
            XCTAssertEqual($0 as? AllyDecisionError, .unsupportedPublicKey)
        }
    }

    // The message starts with the fixed label, then the 16 id bytes, the nonce, one answer
    // byte and 8 bytes of expiry. Pinned so the format cannot drift without a test failing.
    func test_messageFormat() {
        let id = UUID(uuidString: "00112233-4455-6677-8899-AABBCCDDEEFF")!
        let nonce = Data(repeating: 0xAB, count: 32)
        let m = AllyDecisionVerifier.message(requestID: id, nonce: nonce, approved: true, expiresAt: Date(timeIntervalSince1970: 256))
        let label = Data("pawl-ally-decision-v1".utf8)
        XCTAssertEqual(m.prefix(label.count), label)
        XCTAssertEqual(m.count, label.count + 16 + 32 + 1 + 8)
        XCTAssertEqual(m[label.count], 0x00)
        XCTAssertEqual(m[label.count + 15], 0xFF)
        XCTAssertEqual(m[label.count + 16 + 32], 1)
        XCTAssertEqual(Array(m.suffix(8)), [0, 0, 0, 0, 0, 0, 1, 0])
    }

    // Every request gets its own nonce and lives 30 minutes.
    func test_makeRequest_freshNonce() {
        let a = request(), b = request()
        XCTAssertEqual(a.nonce.count, 32)
        XCTAssertNotEqual(a.nonce, b.nonce)
        XCTAssertNotEqual(a.id, b.id)
        XCTAssertEqual(a.expiresAt, t0.addingTimeInterval(30 * 60))
    }
}
