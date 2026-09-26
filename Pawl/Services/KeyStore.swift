// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  KeyStore.swift
//  Pawl — iOS integration layer
//
//  Persists the paired FIDO2 security key (credential ID, public key, signature counter)
//  in the Keychain, plus a pending re-pair (FR-NFC-004). 2.0 kept only the credential ID,
//  in UserDefaults, under NFC-era names ("pawl.key.uid"). On first launch of 2.1 those
//  values are copied into the Keychain and then removed from UserDefaults.
//
//  Keychain items use kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly: they never sync to
//  iCloud or move to another phone. Note: unlike UserDefaults, Keychain items can outlive
//  deleting the app. Deleting Pawl is blocked while a commitment is active, and a later
//  reinstall simply finds the same paired key.
//

import Foundation
import Security

@MainActor
public final class KeyStore {

    /// A re-pair in progress: the NEW key plus when its cooling-off ends. The ACTIVE key is left
    /// untouched until the wait elapses, so re-pairing can't grant an instantly usable key
    /// (FR-NFC-004). Persisted so force-quitting can't skip the wait.
    nonisolated private struct PendingKey: Codable {
        var key: RegisteredKey
        var endsAt: Date
    }

    private static let service = "io.github.jasonepage.Pawl.securityKey"
    private static let activeAccount = "pawl.key.credential"
    private static let pendingAccount = "pawl.key.pendingCredential"

    // 2.0 UserDefaults keys, read once for migration and then deleted.
    private static let legacyActive = "pawl.key.uid"
    private static let legacyPending = "pawl.key.pending.uid"
    private static let legacyPendingEnds = "pawl.key.pending.endsAt"

    private let legacyDefaults: UserDefaults

    /// Whether a key is paired. `.unavailable` means the Keychain could not be read (for
    /// example before the phone's first unlock after a restart). Callers must treat it like
    /// `.paired` for anything that loosens protection: never offer a free first pairing on it.
    public enum PairingState: Equatable { case paired, unpaired, unavailable }

    private enum ReadResult<T> { case found(T), notFound, error }

    public init(suiteName: String? = nil) {
        self.legacyDefaults = suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
        migrateFromUserDefaults()
    }

    // MARK: - Active key

    @discardableResult
    public func save(_ key: RegisteredKey) -> Bool { write(key, account: Self.activeAccount) }
    public func load() -> RegisteredKey? {
        // Fall back to the 2.0 value if migration couldn't write the Keychain yet.
        if case .found(let key) = read(RegisteredKey.self, account: Self.activeAccount) { return key }
        return legacyActiveKey()
    }

    /// Read fresh every time; don't cache it across a pairing decision.
    public func state() -> PairingState {
        switch read(RegisteredKey.self, account: Self.activeAccount) {
        case .found: return .paired
        case .error: return legacyActiveKey() != nil ? .paired : .unavailable
        case .notFound: return legacyActiveKey() != nil ? .paired : .unpaired
        }
    }
    public func clear() {
        delete(account: Self.activeAccount)
        legacyDefaults.removeObject(forKey: Self.legacyActive)
    }

    // MARK: - Pending re-pair (gated key change)

    @discardableResult
    public func savePending(_ key: RegisteredKey, endsAt: Date) -> Bool {
        write(PendingKey(key: key, endsAt: endsAt), account: Self.pendingAccount)
    }

    public func loadPending() -> (key: RegisteredKey, endsAt: Date)? {
        if case .found(let pending) = read(PendingKey.self, account: Self.pendingAccount) {
            return (pending.key, pending.endsAt)
        }
        return legacyPendingKey()
    }

    public func clearPending() {
        delete(account: Self.pendingAccount)
        legacyDefaults.removeObject(forKey: Self.legacyPending)
        legacyDefaults.removeObject(forKey: Self.legacyPendingEnds)
    }

    // MARK: - Migration from 2.0

    /// Copies 2.0 values into the Keychain if it has none, then deletes them from UserDefaults.
    /// The old values are only deleted after the Keychain write succeeds. A 2.0 key has no
    /// stored public key, so its signature can't be checked until it is re-paired
    /// (see WebAuthnVerifier.swift).
    private func migrateFromUserDefaults() {
        if let legacy = legacyActiveKey() {
            if case .found = read(RegisteredKey.self, account: Self.activeAccount) {
                legacyDefaults.removeObject(forKey: Self.legacyActive)
            } else if case .notFound = read(RegisteredKey.self, account: Self.activeAccount), save(legacy) {
                legacyDefaults.removeObject(forKey: Self.legacyActive)
            }
        }
        if let legacy = legacyPendingKey() {
            if case .found = read(PendingKey.self, account: Self.pendingAccount) {
                legacyDefaults.removeObject(forKey: Self.legacyPending)
                legacyDefaults.removeObject(forKey: Self.legacyPendingEnds)
            } else if case .notFound = read(PendingKey.self, account: Self.pendingAccount),
                      savePending(legacy.key, endsAt: legacy.endsAt) {
                legacyDefaults.removeObject(forKey: Self.legacyPending)
                legacyDefaults.removeObject(forKey: Self.legacyPendingEnds)
            }
        }
    }

    private func legacyActiveKey() -> RegisteredKey? {
        guard let uid = legacyDefaults.string(forKey: Self.legacyActive),
              let id = Data(base64Encoded: uid) else { return nil }
        return RegisteredKey(credentialID: id, publicKey: nil, signCount: 0)
    }

    private func legacyPendingKey() -> (key: RegisteredKey, endsAt: Date)? {
        guard let uid = legacyDefaults.string(forKey: Self.legacyPending),
              let id = Data(base64Encoded: uid) else { return nil }
        let ts = legacyDefaults.double(forKey: Self.legacyPendingEnds)
        guard ts > 0 else { return nil }
        return (RegisteredKey(credentialID: id, publicKey: nil, signCount: 0), Date(timeIntervalSince1970: ts))
    }

    // MARK: - Keychain

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

    private func read<T: Decodable>(_ type: T.Type, account: String) -> ReadResult<T> {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return .notFound }
        guard status == errSecSuccess, let data = result as? Data,
              let value = try? JSONDecoder().decode(T.self, from: data) else { return .error }
        return .found(value)
    }

    private func delete(account: String) {
        _ = SecItemDelete(baseQuery(account: account) as CFDictionary)
    }
}
