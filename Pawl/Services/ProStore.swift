// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  ProStore.swift
//  Pawl — 2.0 (P1: Pawl Pro subscription)
//
//  StoreKit 2 entitlement manager for Pawl Pro. Pro gates the ACCOUNTABILITY layer
//  (link-your-own-sponsor + tamper alerts); the solo blocking loop, crisis tools, and the
//  approver side stay free (docs/12 §2). This type is the single source of truth for `isPro`.
//  AppModel composes it into a `hasAccountability` gate (Pro OR grandfathered) in a later slice.
//
//  StoreKit 2 APIs used here are stable since iOS 15. Product IDs + prices live in App Store
//  Connect (and a local Configuration.storekit for testing) — see docs/12 §3–§4. This file
//  was written without a compiler; the calls are standard StoreKit 2, but eyeball them against
//  Xcode autocomplete on the first build (repo discipline).
//

import Foundation
import StoreKit

@MainActor
@Observable
public final class ProStore {

    // MARK: - Product identifiers (confirm in App Store Connect — docs/12 §3, §12-6)
    public static let yearlyID  = "io.github.jasonepage.Pawl.pro.yearly"
    public static let monthlyID = "io.github.jasonepage.Pawl.pro.monthly"
    private static let productIDs: Set<String> = [yearlyID, monthlyID]

    // MARK: - Published state
    /// Loaded products (yearly first), for the paywall.
    public private(set) var products: [Product] = []
    /// True when an active, non-revoked Pro entitlement exists. Seeded from the App Group cache
    /// so gating works offline and on cold launch, then recomputed from StoreKit.
    public private(set) var isPro: Bool = false
    /// Which Pro product IDs are currently entitled (so the UI can show the active plan).
    public private(set) var purchasedProductIDs: Set<String> = []
    /// Last user-facing error from load/purchase/restore (nil when clear).
    public private(set) var lastError: String?

    /// Grandfather flag (docs/12 §2a-2): set by AppModel on first Pro-build launch if an active
    /// sponsor link already exists → accountability stays free for life. Persisted to the App Group.
    public var isLegacyFree: Bool {
        didSet { Self.defaults?.set(isLegacyFree, forKey: Self.legacyKey) }
    }

    // The Transaction.updates listener. ProStore is created once by AppModel and lives for the
    // whole process, and the task holds self weakly (no retain cycle), so there is deliberately
    // no deinit cancellation — that would need main-actor access from a nonisolated deinit.
    private var updatesListener: Task<Void, Never>?

    public init() {
        isLegacyFree = Self.defaults?.bool(forKey: Self.legacyKey) ?? false
        isPro = Self.cachedIsPro()
        // Apply renewals / refunds / revocations / family-sharing changes as they arrive,
        // without requiring a relaunch (docs/12 §6).
        updatesListener = listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    // MARK: - Loading

    public func loadProducts() async {
        do {
            let loaded = try await Product.products(for: Self.productIDs)
            products = loaded.sorted { lhs, rhs in
                if lhs.id == Self.yearlyID { return true }    // yearly first
                if rhs.id == Self.yearlyID { return false }
                return lhs.price < rhs.price
            }
            #if DEBUG
            let summary = products.map { "\($0.id)=\($0.displayPrice)" }.joined(separator: ", ")
            print("[ProStore] loaded \(products.count) product(s): \(summary)")
            #endif
        } catch {
            lastError = error.localizedDescription
            #if DEBUG
            print("[ProStore] product load failed: \(error)")
            #endif
        }
    }

    // MARK: - Purchase

    /// Returns true if the purchase completed and Pro is now active. `.pending` (Ask to Buy) and
    /// `.userCancelled` return false without surfacing an error.
    @discardableResult
    public func purchase(_ product: Product) async -> Bool {
        do {
            switch try await product.purchase() {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                return isPro
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    // MARK: - Restore (required by App Review — docs/12 §9)

    public func restore() async {
        do { try await AppStore.sync() }
        catch { lastError = error.localizedDescription }
        await refreshEntitlements()
    }

    // MARK: - Entitlement computation

    /// Recompute `isPro` from current entitlements. `Transaction.currentEntitlements` already
    /// excludes expired subscriptions and includes ones in a billing grace period, so it is the
    /// correct v1 source of truth (docs/12 §6). Caches the result for offline gating.
    public func refreshEntitlements() async {
        if products.isEmpty { await loadProducts() }   // status check below needs a loaded product

        var active: Set<String> = []
        #if DEBUG
        var dbgEntitlements: [String] = []
        var dbgStatuses: [String] = []
        #endif

        // 1) Current entitlements — covers purchased + most active subscription states.
        for await result in Transaction.currentEntitlements {
            guard let t = try? checkVerified(result) else { continue }
            #if DEBUG
            dbgEntitlements.append("\(t.productID)\(t.revocationDate == nil ? "" : " [revoked]")")
            #endif
            if t.revocationDate == nil, Self.productIDs.contains(t.productID) {
                active.insert(t.productID)
            }
        }

        // 2) Subscription group status — catches a FREE TRIAL / intro offer / grace / billing-retry,
        //    which can be absent from currentEntitlements. Any active state counts as entitled
        //    (docs/12 §6). This is what fixes the trialing yearly plan reading as "Free".
        if let sub = products.first(where: { $0.subscription != nil })?.subscription,
           let statuses = try? await sub.status {
            for status in statuses {
                guard case .verified(let t) = status.transaction else { continue }
                #if DEBUG
                dbgStatuses.append("\(t.productID)=\(String(describing: status.state))")
                #endif
                let entitled = status.state == .subscribed
                    || status.state == .inGracePeriod
                    || status.state == .inBillingRetryPeriod
                if entitled, t.revocationDate == nil, Self.productIDs.contains(t.productID) {
                    active.insert(t.productID)
                }
            }
        }

        purchasedProductIDs = active
        isPro = !active.isEmpty
        Self.cacheIsPro(isPro)
        #if DEBUG
        print("[ProStore] refreshEntitlements → isPro=\(isPro), active=\(active); " +
              "currentEntitlements=[\(dbgEntitlements.joined(separator: ", "))]; " +
              "status=[\(dbgStatuses.joined(separator: ", "))]")
        #endif
    }

    // MARK: - Transaction.updates listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await update in Transaction.updates {
                await self?.apply(update)
            }
        }
    }

    private func apply(_ result: VerificationResult<Transaction>) async {
        guard let transaction = try? checkVerified(result) else { return }
        await transaction.finish()
        await refreshEntitlements()
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let safe):       return safe
        }
    }

    // MARK: - Offline cache (App Group — shared id from HANDOFF §4)

    private nonisolated static let appGroup  = "group.io.github.jasonepage.Pawl"
    private nonisolated static let proKey    = "pawl.pro.isPro"
    private nonisolated static let legacyKey = "pawl.pro.isLegacyFree"
    private nonisolated static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }
    private nonisolated static func cachedIsPro() -> Bool { defaults?.bool(forKey: proKey) ?? false }
    private nonisolated static func cacheIsPro(_ value: Bool) { defaults?.set(value, forKey: proKey) }

    // Grandfather evaluation marker (one-time). See AppModel.applyGrandfatherIfNeeded (docs/12 §2a-2).
    private nonisolated static let evaluatedKey = "pawl.pro.grandfatherEvaluated"
    public nonisolated static var grandfatherEvaluated: Bool { defaults?.bool(forKey: evaluatedKey) ?? false }
    public nonisolated static func markGrandfatherEvaluated() { defaults?.set(true, forKey: evaluatedKey) }

    #if DEBUG
    /// Dev-only: clear grandfather/legacy so the paywall gate can be tested from a non-entitled state.
    /// Combine with Xcode → StoreKit → Manage Transactions to remove any active subscription.
    public func debugResetLegacy() {
        isLegacyFree = false
        Self.defaults?.set(false, forKey: Self.evaluatedKey)
    }
    #endif
}
