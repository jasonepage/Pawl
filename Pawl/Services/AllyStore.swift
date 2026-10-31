// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  AllyStore.swift
//  Pawl: iOS integration layer (2.4, docs/18 section 4.3 and 4.7)
//
//  What each phone remembers about an ally pairing, in the Keychain, this device only.
//
//  Owner's phone (the person being protected):
//    - the ally's public signing key and first name, plus the iCloud zone the share lives in.
//      The saved public key is the copy that counts: a Decision is checked against it, never
//      against whatever is in iCloud at the time.
//
//  Ally's phone:
//    - its own Secure Enclave signing key (the private half never leaves the chip), the
//      owner's zone, and the owner's name. This is the `ally` role. It is a new name on
//      purpose: 2.3's retireApproverRole() still wipes anything saved as `approver`.
//
//  Keychain items use kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, like KeyStore: they
//  never sync and never move to another phone. The whole point is that the ally's yes can only
//  come from the ally's phone.
//

import Foundation
import Security
import CryptoKit

/// Where a shared zone lives, in plain Codable form (CKRecordZone.ID is not Codable).
nonisolated public struct AllyZoneRef: Codable, Equatable, Sendable {
    public var zoneName: String
    public var ownerName: String
    public init(zoneName: String, ownerName: String) {
        self.zoneName = zoneName
        self.ownerName = ownerName
    }
}

/// The owner's record of their one ally (D6: one ally).
nonisolated public struct AllyPairing: Codable, Equatable, Sendable {
    /// Uncompressed P-256 public key (0x04 || X || Y) from the ally's Secure Enclave key.
    public var publicKey: Data
    /// The first name the ally typed. Shown as "Your ally: Sam". Nothing else about them.
    public var name: String
    public var zone: AllyZoneRef
    public var pairedAt: Date
    public init(publicKey: Data, name: String, zone: AllyZoneRef, pairedAt: Date) {
        self.publicKey = publicKey
        self.name = name
        self.zone = zone
        self.pairedAt = pairedAt
    }
}

/// The ally's record of the one person they help.
nonisolated public struct AllyRole: Codable, Equatable, Sendable {
    /// `SecureEnclave.P256.Signing.PrivateKey.dataRepresentation`: an encrypted blob only this
    /// phone's Secure Enclave can use. Not the private key itself.
    public var signingKeyBlob: Data
    /// The name the ally typed for themselves, sent to the owner once in the AllyLink record.
    public var myName: String
    /// The owner's first name, from the share's owner identity (or typed if iCloud hides it).
    public var ownerName: String
    public var zone: AllyZoneRef
    public var joinedAt: Date
    public init(signingKeyBlob: Data, myName: String, ownerName: String, zone: AllyZoneRef, joinedAt: Date) {
        self.signingKeyBlob = signingKeyBlob
        self.myName = myName
        self.ownerName = ownerName
        self.zone = zone
        self.joinedAt = joinedAt
    }
}

@MainActor
public final class AllyStore {
    public static let shared = AllyStore()

    private static let service = "io.github.jasonepage.Pawl.ally"
    private static let pairingAccount = "pawl.ally.pairing"       // owner side
    private static let roleAccount = "pawl.ally.role"             // ally side

    private init() {}

    // MARK: - Owner side

    public func pairing() -> AllyPairing? { read(AllyPairing.self, account: Self.pairingAccount) }

    @discardableResult
    public func savePairing(_ pairing: AllyPairing) -> Bool { write(pairing, account: Self.pairingAccount) }

    /// Removing an ally blocks more, so it is instant and needs no key (docs/18 section 4.4).
    public func removePairing() { delete(account: Self.pairingAccount) }

    // MARK: - Ally side

    public func role() -> AllyRole? { read(AllyRole.self, account: Self.roleAccount) }

    @discardableResult
    public func saveRole(_ role: AllyRole) -> Bool { write(role, account: Self.roleAccount) }

    public func clearRole() { delete(account: Self.roleAccount) }

    /// Make the ally's signing key in the Secure Enclave. The public half goes to the owner.
    /// Throws on phones without a Secure Enclave (the simulator, some iPads), in which case
    /// the person cannot be an ally; the owner's key still works.
    public static func makeSigningKey() throws -> SecureEnclave.P256.Signing.PrivateKey {
        // Every signature asks for Face ID, Touch ID or the passcode (docs/18 section 1: "taps
        // Approve, then confirms with Face ID"). A phone left on a table cannot say yes.
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                           [.privateKeyUsage, .userPresence], &error) else {
            throw error?.takeRetainedValue() ?? CocoaError(.coderInvalidValue)
        }
        return try SecureEnclave.P256.Signing.PrivateKey(accessControl: access)
    }

    /// Reopen the saved signing key for one signature.
    public func signingKey() throws -> SecureEnclave.P256.Signing.PrivateKey? {
        guard let role = role() else { return nil }
        return try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: role.signingKeyBlob)
    }

    // MARK: - Keychain (same shape as KeyStore)

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
        ]
    }

    private func write<T: Encodable>(_ value: T, account: String) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else { return false }
        let query = baseQuery(account: account)
        let update: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        var add = query
        add.merge(update) { _, new in new }
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    private func read<T: Decodable>(_ type: T.Type, account: String) -> T? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func delete(account: String) {
        _ = SecItemDelete(baseQuery(account: account) as CFDictionary)
    }
}
