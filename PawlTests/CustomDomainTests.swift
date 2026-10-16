// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  CustomDomainTests.swift
//  PawlTests (2.2)
//
//  The hostname cleaner behind the typed website list and the fetched gambling list.
//

import XCTest
@testable import Pawl

final class CustomDomainTests: XCTestCase {

    func testPlainHostnamePasses() {
        XCTAssertEqual(BlocklistService.cleanHostname("example.com"), "example.com")
    }

    func testStripsSchemeWwwPathQueryPortAndCase() {
        XCTAssertEqual(BlocklistService.cleanHostname("HTTPS://WWW.DraftKings.com/sports?x=1"), "draftkings.com")
        XCTAssertEqual(BlocklistService.cleanHostname("http://example.com:8080/"), "example.com")
        XCTAssertEqual(BlocklistService.cleanHostname("  bet365.com  "), "bet365.com")
    }

    func testKeepsSubdomains() {
        XCTAssertEqual(BlocklistService.cleanHostname("sportsbook.fanduel.com"), "sportsbook.fanduel.com")
    }

    func testRejectsBlanksCommentsAndNonHostnames() {
        XCTAssertNil(BlocklistService.cleanHostname(""))
        XCTAssertNil(BlocklistService.cleanHostname("   "))
        XCTAssertNil(BlocklistService.cleanHostname("# a comment"))
        XCTAssertNil(BlocklistService.cleanHostname("localhost"))
        XCTAssertNil(BlocklistService.cleanHostname("just some words"))
        XCTAssertNil(BlocklistService.cleanHostname(".example.com"))
        XCTAssertNil(BlocklistService.cleanHostname("example.com."))
        XCTAssertNil(BlocklistService.cleanHostname("exa mple.com"))
    }

    func testNormalizedMergeStillDedupesAndKeepsSeed() {
        let merged = BlocklistService.normalizedMerge(["WWW.A.com", "a.com", "https://b.com/x"], seed: ["seed.com"])
        XCTAssertEqual(Set(merged), ["a.com", "b.com", "seed.com"])
    }
}
