// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  AllyCloudMappingTests.swift
//  PawlTests: 2.5 step 2
//
//  The CloudKit record shapes, checked without an iCloud account: a CKRecord can be built and
//  read in memory. The network parts of AllyCloud are checked by hand on two phones.
//

import XCTest
import CloudKit
@testable import Pawl

final class AllyCloudMappingTests: XCTestCase {

    private let zone = CKRecordZone.ID(zoneName: "Ally", ownerName: CKCurrentUserDefaultName)

    @MainActor
    func test_requestRoundTrip() throws {
        let request = AllyRequest.make(kind: .blockLess, now: Date(timeIntervalSince1970: 5_000))
        let record = CKRecord(recordType: "Request", recordID: CKRecord.ID(recordName: "request", zoneID: zone))
        record["id"] = request.id.uuidString
        record["kind"] = request.kind.rawValue
        record["createdAt"] = request.createdAt
        record["expiresAt"] = request.expiresAt
        record["nonce"] = request.nonce
        XCTAssertEqual(try AllyCloud.request(from: record), request)
    }

    @MainActor
    func test_decisionRoundTrip() throws {
        let decision = AllyDecision(requestID: UUID(), approved: true,
                                    signedAt: Date(timeIntervalSince1970: 6_000), signature: Data(repeating: 9, count: 64))
        let record = CKRecord(recordType: "Decision", recordID: CKRecord.ID(recordName: "decision", zoneID: zone))
        record["requestID"] = decision.requestID.uuidString
        record["approved"] = 1
        record["signedAt"] = decision.signedAt
        record["signature"] = decision.signature
        XCTAssertEqual(try AllyCloud.decision(from: record), decision)
    }

    // A record missing a field, or with a short nonce, is refused rather than guessed at.
    @MainActor
    func test_malformedRecords_refused() {
        let record = CKRecord(recordType: "Request", recordID: CKRecord.ID(recordName: "request", zoneID: zone))
        record["id"] = UUID().uuidString
        record["kind"] = "unlock"
        record["createdAt"] = Date()
        record["expiresAt"] = Date()
        record["nonce"] = Data(repeating: 1, count: 8)
        XCTAssertThrowsError(try AllyCloud.request(from: record))

        let decision = CKRecord(recordType: "Decision", recordID: CKRecord.ID(recordName: "decision", zoneID: zone))
        decision["requestID"] = "not a uuid"
        XCTAssertThrowsError(try AllyCloud.decision(from: decision))
    }

    // The kinds the ally can see are exactly these two words (D5).
    func test_requestKinds() {
        XCTAssertEqual(AllyRequestKind.unlock.rawValue, "unlock")
        XCTAssertEqual(AllyRequestKind.blockLess.rawValue, "blockLess")
    }
}
