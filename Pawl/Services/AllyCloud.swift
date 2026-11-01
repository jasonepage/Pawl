// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  AllyCloud.swift
//  Pawl: iOS integration layer (2.4, docs/18 sections 4.1, 4.2, 4.4)
//
//  Everything ally approvals do in iCloud, and nothing else does. There is no Pawl server:
//  this talks to Apple's CloudKit, inside the owner's own iCloud. The developer cannot read it.
//
//  Shape:
//    - The owner has a private zone named `Ally`. One CKShare covers the whole zone.
//    - The ally accepts the share link and sees the zone in their shared database.
//    - Three records, each with a FIXED record name so nothing here needs a query or an index:
//        allyLink   written once by the ally: public key, name
//        request    written by the owner: id, kind, created, expires, nonce. Deleted when done.
//        decision   written by the ally: request id, approved, signed time, signature.
//                   Deleted by the owner once read.
//      One ally, one open request at a time (UnlockMachine allows one), so one of each is enough.
//
//  Rules kept here:
//    - The shield never waits on this. Nothing in ShieldService or the extensions calls it.
//    - No app names, sites, slips, urges, notes or streaks go in any record.
//    - A record's creator is checked at pairing so the owner's own iPad on the same Apple
//      Account cannot play the ally (docs/18 section 4.3 point 6).
//
//  Nothing is wired to the UI yet (step 4). Pushes are step 3.
//

import Foundation
import CloudKit

nonisolated public enum AllyCloudError: Error, Equatable, Sendable {
    case notSignedIn            // no iCloud account on this phone
    case noShare                // the owner has not made a share yet
    case allyNotJoined          // nobody has accepted the share
    case allyIsOwner            // the "ally" record was made by the owner's own Apple Account
    case allyNotParticipant     // the record's creator is not someone the share was sent to
    case malformedRecord
    case noRole                 // this phone is not set up as an ally
}

@MainActor
public final class AllyCloud {
    public static let shared = AllyCloud()

    static let zoneName = "Ally"
    static let linkRecordType = "AllyLink", linkRecordName = "allyLink"
    static let requestRecordType = "Request", requestRecordName = "request"
    static let decisionRecordType = "Decision", decisionRecordName = "decision"

    /// The container, for the share sheet (CKShareTransferRepresentation needs it).
    public let container: CKContainer
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private var sharedDB: CKDatabase { container.sharedCloudDatabase }

    private init() {
        container = CKContainer(identifier: PawlConfig.cloudKitContainer)
    }

    /// True when the phone is signed in to iCloud. Both sides need this; neither needs Pro here.
    public func isSignedIn() async -> Bool {
        (try? await container.accountStatus()) == .available
    }

    // MARK: - Owner: zone and share (step 2)

    private var ownZoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: Self.zoneName, ownerName: CKCurrentUserDefaultName)
    }

    /// Make the `Ally` zone if it is not there. Safe to call every time.
    public func ensureZone() async throws {
        _ = try await privateDB.save(CKRecordZone(zoneID: ownZoneID))
    }

    /// The share for the whole zone, making it if needed. Its `url` is the invite the owner
    /// sends by Messages. Private link: only someone the owner sends it to can accept.
    public func share() async throws -> CKShare {
        try await ensureZone()
        if let existing = try await existingShare() { return existing }
        let share = CKShare(recordZoneID: ownZoneID)
        share[CKShare.SystemFieldKey.title] = "Be my Pawl ally"
        share.publicPermission = .none
        let result = try await privateDB.modifyRecords(saving: [share], deleting: [], savePolicy: .allKeys, atomically: true)
        // modifyRecords reports a failed save inside the results, not by throwing. Surface it.
        for (_, r) in result.saveResults {
            switch r {
            case .success(let rec): if let s = rec as? CKShare { return s }
            case .failure(let error): throw error
            }
        }
        throw AllyCloudError.noShare
    }

    private func existingShare() async throws -> CKShare? {
        let id = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: ownZoneID)
        do { return try await privateDB.record(for: id) as? CKShare }
        catch let e as CKError where e.code == .unknownItem { return nil }
    }

    /// Whether someone other than the owner has accepted the share.
    public func allyHasJoined() async throws -> Bool {
        guard let share = try await existingShare() else { return false }
        return share.participants.contains { $0.role != .owner && $0.acceptanceStatus == .accepted }
    }

    /// Read the ally's pairing record and check who made it (docs/18 section 4.3 point 6).
    /// Returns what the owner should save in the Keychain. The saved copy is what counts
    /// from then on; this record is never read again for verification.
    public func fetchAllyLink() async throws -> AllyPairing {
        guard let share = try await existingShare() else { throw AllyCloudError.noShare }
        let id = CKRecord.ID(recordName: Self.linkRecordName, zoneID: ownZoneID)
        let record: CKRecord
        do { record = try await privateDB.record(for: id) }
        catch let e as CKError where e.code == .unknownItem { throw AllyCloudError.allyNotJoined }

        // Who wrote it? The owner's own writes show up as the current-user placeholder, and
        // anything matching the owner's real record ID is also the owner.
        let me = try await container.userRecordID()
        guard let creator = record.creatorUserRecordID,
              creator.recordName != CKCurrentUserDefaultName,
              creator != me
        else { throw AllyCloudError.allyIsOwner }
        let joined = share.participants.contains {
            $0.role != .owner && $0.acceptanceStatus == .accepted && $0.userIdentity.userRecordID == creator
        }
        guard joined else { throw AllyCloudError.allyNotParticipant }

        guard let publicKey = record["publicKey"] as? Data, publicKey.count == 65, publicKey.first == 0x04,
              let name = record["name"] as? String
        else { throw AllyCloudError.malformedRecord }
        return AllyPairing(publicKey: publicKey,
                           name: String(name.prefix(40)),
                           zone: AllyZoneRef(zoneName: ownZoneID.zoneName, ownerName: ownZoneID.ownerName),
                           pairedAt: Date())
    }

    /// Removing the ally blocks more, so it is instant. Deleting the zone deletes the share,
    /// every record in it, and the ally's access, all at once. The Keychain pairing is removed
    /// by the caller (AllyStore.removePairing) first, so nothing can be verified in between.
    public func removeAlly() async throws {
        do { try await privateDB.deleteRecordZone(withID: ownZoneID) }
        catch let e as CKError where e.code == .zoneNotFound { }
    }

    // MARK: - Owner: requests and decisions

    /// Write (or replace) the one open request. Called for the `sendAllyRequest` effect.
    public func writeRequest(_ request: AllyRequest) async throws {
        let record = CKRecord(recordType: Self.requestRecordType,
                              recordID: CKRecord.ID(recordName: Self.requestRecordName, zoneID: ownZoneID))
        record["id"] = request.id.uuidString
        record["kind"] = request.kind.rawValue
        record["createdAt"] = request.createdAt
        record["expiresAt"] = request.expiresAt
        record["nonce"] = request.nonce
        try Self.check(try await privateDB.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys, atomically: true))
    }

    /// Delete the open request and any decision. Called for the `withdrawAllyRequest` effect,
    /// and after a decision is accepted so the same yes can never be read twice.
    public func deleteRequest() async throws {
        let ids = [Self.requestRecordName, Self.decisionRecordName].map { CKRecord.ID(recordName: $0, zoneID: ownZoneID) }
        _ = try await privateDB.modifyRecords(saving: [], deleting: ids, savePolicy: .allKeys, atomically: false)
    }

    /// The ally's answer, if one has arrived. Checking it is AllyDecisionVerifier's job.
    public func fetchDecision() async throws -> AllyDecision? {
        let id = CKRecord.ID(recordName: Self.decisionRecordName, zoneID: ownZoneID)
        do { return try Self.decision(from: try await privateDB.record(for: id)) }
        catch let e as CKError where e.code == .unknownItem { return nil }
    }

    // MARK: - Ally side

    /// Accept an invite link. iOS hands the app the share metadata when the link is opened
    /// (needs `CKSharingSupported` in Info.plist). Returns where the zone lives and the
    /// owner's name as iCloud shows it, which may be empty.
    public func acceptShare(_ metadata: CKShare.Metadata) async throws -> (zone: AllyZoneRef, ownerName: String) {
        let share = try await container.accept(metadata)
        let zoneID = share.recordID.zoneID
        let name = share.owner.userIdentity.nameComponents?.givenName ?? ""
        return (AllyZoneRef(zoneName: zoneID.zoneName, ownerName: zoneID.ownerName), name)
    }

    private func zoneID(_ ref: AllyZoneRef) -> CKRecordZone.ID {
        CKRecordZone.ID(zoneName: ref.zoneName, ownerName: ref.ownerName)
    }

    /// Write the pairing record once: the public half of this phone's Secure Enclave key and
    /// the ally's first name. Nothing else about the ally ever goes in.
    public func writeAllyLink(publicKey: Data, name: String, zone: AllyZoneRef) async throws {
        let record = CKRecord(recordType: Self.linkRecordType,
                              recordID: CKRecord.ID(recordName: Self.linkRecordName, zoneID: zoneID(zone)))
        record["publicKey"] = publicKey
        record["name"] = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        try Self.check(try await sharedDB.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys, atomically: true))
    }

    /// The open request, if the owner has one. The ally sees only this (D5).
    public func fetchOpenRequest(zone: AllyZoneRef) async throws -> AllyRequest? {
        let id = CKRecord.ID(recordName: Self.requestRecordName, zoneID: zoneID(zone))
        do { return try Self.request(from: try await sharedDB.record(for: id)) }
        catch let e as CKError where e.code == .unknownItem { return nil }
    }

    /// Write the signed answer. The owner's phone deletes it once read.
    public func writeDecision(_ decision: AllyDecision, zone: AllyZoneRef) async throws {
        let record = CKRecord(recordType: Self.decisionRecordType,
                              recordID: CKRecord.ID(recordName: Self.decisionRecordName, zoneID: zoneID(zone)))
        record["requestID"] = decision.requestID.uuidString
        record["approved"] = (decision.approved ? 1 : 0)
        record["signedAt"] = decision.signedAt
        record["signature"] = decision.signature
        try Self.check(try await sharedDB.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys, atomically: true))
    }

    /// The ally leaves. Deleting the share record from the shared database removes this
    /// participant. The owner's phone then sees no participant and shows "Your ally left."
    public func leave(zone: AllyZoneRef) async throws {
        let id = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID(zone))
        do { try await sharedDB.deleteRecord(withID: id) }
        catch let e as CKError where e.code == .unknownItem || e.code == .zoneNotFound { }
    }

    // MARK: - Pushes (step 3, docs/18 section 4.6)

    /// Subscription ids. One per side; saving the same id again is a harmless replace.
    static let ownerSubscriptionID = "pawl-ally-owner"
    static let allySubscriptionID = "pawl-ally-ally"

    /// Owner: a silent push when anything in the private database changes, so the app can
    /// fetch the ally's answer in the background. No banner: the owner is the one who asked.
    public func subscribeOwner() async throws {
        let sub = CKDatabaseSubscription(subscriptionID: Self.ownerSubscriptionID)
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        sub.notificationInfo = info
        _ = try await privateDB.modifySubscriptions(saving: [sub], deleting: [])
    }

    /// Ally: a banner when the owner writes a request. The text is generic on purpose: the
    /// push goes through Apple's servers and the lock screen, so the kind of request and
    /// anything else stays inside the app (D5).
    public func subscribeAlly(ownerName: String) async throws {
        let sub = CKDatabaseSubscription(subscriptionID: Self.allySubscriptionID)
        let info = CKSubscription.NotificationInfo()
        let who = ownerName.isEmpty ? "Someone" : ownerName
        info.alertBody = "\(who) is asking you in Pawl."
        info.soundName = "default"
        info.shouldSendContentAvailable = true
        sub.notificationInfo = info
        _ = try await sharedDB.modifySubscriptions(saving: [sub], deleting: [])
    }

    public func unsubscribeOwner() async {
        _ = try? await privateDB.modifySubscriptions(saving: [], deleting: [Self.ownerSubscriptionID])
    }

    public func unsubscribeAlly() async {
        _ = try? await sharedDB.modifySubscriptions(saving: [], deleting: [Self.allySubscriptionID])
    }

    /// A failed save inside a modifyRecords result becomes a thrown error.
    static func check(_ result: (saveResults: [CKRecord.ID: Result<CKRecord, Error>], deleteResults: [CKRecord.ID: Result<Void, Error>])) throws {
        for (_, r) in result.saveResults { if case .failure(let e) = r { throw e } }
    }

    // MARK: - Record mapping

    static func request(from r: CKRecord) throws -> AllyRequest {
        guard let idString = r["id"] as? String, let id = UUID(uuidString: idString),
              let kindRaw = r["kind"] as? String, let kind = AllyRequestKind(rawValue: kindRaw),
              let createdAt = r["createdAt"] as? Date,
              let expiresAt = r["expiresAt"] as? Date,
              let nonce = r["nonce"] as? Data, nonce.count == 32
        else { throw AllyCloudError.malformedRecord }
        return AllyRequest(id: id, kind: kind, createdAt: createdAt, expiresAt: expiresAt, nonce: nonce)
    }

    static func decision(from r: CKRecord) throws -> AllyDecision {
        guard let idString = r["requestID"] as? String, let id = UUID(uuidString: idString),
              let approvedInt = r["approved"] as? Int64,
              let signedAt = r["signedAt"] as? Date,
              let signature = r["signature"] as? Data
        else { throw AllyCloudError.malformedRecord }
        return AllyDecision(requestID: id, approved: approvedInt != 0, signedAt: signedAt, signature: signature)
    }
}
