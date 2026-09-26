// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  AppModel.swift
//  Pawl — app-wide state
//
//  Single source of truth for shared services + whether the user has onboarded, and
//  the one place a commitment is created (at activation). Ties the journey together:
//  Screen Time auth → chosen targets → paired key → active commitment + shield.
//

import Foundation
import FamilyControls
import Supabase

/// Who this person is using Pawl as. A blocker sets up the shield for themselves; an
/// approver only signs in and approves someone else's unlocks (no blocking on their phone).
enum AppRole: String { case blocker, approver }

@MainActor
@Observable
final class AppModel {
    var didOnboard: Bool
    /// Defaults to .blocker so anyone who onboarded before roles existed is unchanged.
    var role: AppRole
    /// The user's primary focus (what they're quitting). Tailors onboarding copy + the default
    /// website categories only — the enforcement loop is identical across verticals. Defaults to
    /// .gambling so anyone who onboarded before verticals existed is unchanged (Decision D6).
    var vertical: Vertical

    let auth = AuthorizationService()
    let shield = ShieldService()
    let selectionStore = SelectionStore()
    /// Phase 2: Supabase account (Sign in with Apple). Additive — the solo loop works
    /// signed out (FR-P2-AUTH-005). Sponsor linking + the repository swap build on this.
    let account = AuthService()
    /// Slice 3: invite/redeem a sponsor (FR-P2-LINK-*).
    let sponsor = SponsorService()
    /// Slice 4: create/poll/decide sponsor unlock approvals (FR-P2-SPON-*).
    let approval = UnlockApprovalService()
    /// 2.0 P1: Pawl Pro entitlement (StoreKit 2). Owned here so it loads at launch;
    /// `hasAccountability` below is the single gate views should check (docs/12 §5).
    let pro = ProStore()
    /// Slice 2: Supabase is canonical for the commitment definition, with iCloud as the
    /// offline/reinstall cache underneath (FR-P2-SYNC-001/003/005). Same protocol, so
    /// activate()/load() are unchanged.
    private let repo: CommitmentRepository =
        SupabaseCommitmentRepository(cache: CloudCommitmentRepository())

    /// The active commitment (cache/Supabase reconciled), exposed so the unlock flow can
    /// attach unlock_requests to it.
    private(set) var activeCommitment: Commitment?

    /// Sponsor mode is on exactly while an active sponsor link exists (FR-P2-LINK-005).
    var isSponsorModeActive: Bool {
        sponsor.asProtected.contains { $0.status == "active" }
    }

    /// True when this user approves someone else's unlocks (so the Approvals tab is relevant).
    var isSponsoringSomeone: Bool {
        sponsor.asSponsor.contains { $0.status == "active" }
    }

    /// The accountability gate (docs/12 §5): Pro OR grandfathered. The protected-person sponsor
    /// features check this; the approver side and the crisis tools never do.
    var hasAccountability: Bool { pro.isPro || pro.isLegacyFree }

    /// Links created before 2.0 shipped predate the paywall, so their owners never chose Pro and
    /// keep accountability free for life (docs/12 §2a-2). The date check is what makes the flag
    /// reinstall-proof: the "evaluated" marker lives in the App Group and is wiped by a delete +
    /// reinstall, so without it a subscriber could link a sponsor, cancel, reinstall, and re-run
    /// the grandfather. A post-cutoff link can only have been created by an entitled user, so it
    /// is never grandfathered. Bump only if the public 2.0 release date moves.
    private static let grandfatherCutoff = ISO8601DateFormatter().date(from: "2026-07-02T00:00:00Z")!

    /// One-time grandfather (docs/12 §2a-2): first Pro-build launch with an active PRE-CUTOFF
    /// sponsor link → accountability free for life. Runs once, only with authoritative sponsor
    /// data (signed in + a successful load), and NEVER revokes. Missing created_at fails closed.
    /// Call after `sponsor.refresh()`.
    func applyGrandfatherIfNeeded() {
        guard !ProStore.grandfatherEvaluated else { return }
        guard account.isSignedIn, sponsor.didLoad else { return }
        let hasLegacyLink = sponsor.asProtected.contains { link in
            link.status == "active" && (link.created_at.map { $0 < Self.grandfatherCutoff } ?? false)
        }
        if hasLegacyLink { pro.isLegacyFree = true }
        ProStore.markGrandfatherEvaluated()
    }

    // Friction customization. Tightening (longer cooldown / shorter grace) applies now;
    // loosening waits out the current cooldown so it can't be weakened in the moment.
    private let durationStore = DurationStore()
    private var durationTimer: Task<Void, Never>?
    private(set) var pendingDurations: PendingDurations?

    // Key-gated blocklist editing (FR-SHIELD-010). Adding targets is free; removing one is an
    // unlock action (security key + cooling-off) and the removed targets stay blocked until then.
    private let security = SecurityKeyService()
    private let keyStore = KeyStore()
    private let selectionChangeStore = SelectionChangeStore()
    private var selectionTimer: Task<Void, Never>?
    private(set) var pendingSelectionChange: Date?     // endsAt of a gated removal, if any
    var blockChangeMessage: String?
    var currentSelection: FamilyActivitySelection { selectionStore.load() }

    var cooldownSeconds: TimeInterval { activeCommitment?.coolingOffSeconds ?? PawlDefaults.coolingOffDefault }
    var graceSeconds: TimeInterval { activeCommitment?.graceSeconds ?? PawlDefaults.graceDefault }

    init() {
        didOnboard = OnboardingFlag.isComplete()
        role = OnboardingFlag.role()
        vertical = OnboardingFlag.vertical()
        hardLockAttested = HardLock.isAttested()
        hardLockDate = HardLock.attestedDate()
        // Default web blocking on (gambling sites, no adult filter) before the launch shield
        // re-apply runs, so existing users get it too.
        SharedState.ensureWebDefaults(domains: GamblingBlocklist.seedDomains)
        // Re-assert the uninstall block on every launch for an onboarded blocker, so it
        // survives relaunches and reinstalls (FR-P3-HARD-002). Approvers/not-onboarded are
        // left deletable.
        if didOnboard && role == .blocker {
            shield.setDeletionBlock(true)
        }
    }

    /// Number of gambling/crypto sites currently blocked in Safari — the live App Group list
    /// (seed + any Supabase-fetched domains), not just the bundled seed.
    var webBlockCount: Int {
        max(SharedState.webBlockDomains().count, GamblingBlocklist.seedDomains.count)
    }
    /// Which website categories are blocked (chosen at onboarding; multi-select).
    var gamblingOn: Bool { SharedState.webBlockEnabled() }
    var adultOn: Bool { SharedState.webAdultFilter() }

    /// Whether a physical security key is paired yet. False for someone who finished onboarding via
    /// "I don't have a key yet" — used to nudge them on Home, since unlocking needs a paired key.
    var isKeyPaired: Bool { keyStore.load() != nil }

    /// Set which website categories to block (gambling = our curated list; adult = Apple's
    /// built-in filter). Re-applies the shield immediately when locked so it takes effect now.
    /// Adding a category is free/instant (tightening); a future "remove a category" flow must
    /// be gated like other loosenings (asymmetry principle).
    func setWebCategories(gambling: Bool, adult: Bool) {
        SharedState.setWebBlock(enabled: gambling, adult: adult, domains: GamblingBlocklist.seedDomains)
        if SharedState.phase() == "locked" {
            shield.apply(selectionStore.load())
        }
    }

    /// Re-request Screen Time authorization and, if granted, re-apply protection. Screen Time
    /// authorization is per-install, so it's lost on reinstall even though onboarding state is
    /// restored from iCloud — this is the manual recovery path (Settings → Screen Time access,
    /// FR-AUTH-003 / EDGE-AUTH). Web defaults are re-asserted so gambling sites are blocked again
    /// even if the saved app selection didn't survive the reinstall.
    func reenableScreenTime() async {
        await auth.requestAuthorization()
        guard auth.isApproved else { return }
        SharedState.ensureWebDefaults(domains: GamblingBlocklist.seedDomains)
        shield.apply(selectionStore.load())
        if role == .blocker { shield.setDeletionBlock(true) }
    }

    /// Finish onboarding: persist the selection, apply the shield, create the commitment
    /// (FR-ONBOARD-003, FR-SHIELD-005). Streak starts now.
    func activate(selection: FamilyActivitySelection, vertical: Vertical = .gambling) async {
        selectionStore.save(selection)
        shield.apply(selection)
        shield.setDeletionBlock(true)   // Pawl can't be uninstalled while protecting (FR-P3-HARD-002)

        let now = Date()
        let commitment = Commitment(startedAt: now, updatedAt: now)
        let blockSet = BlockSet(
            commitmentID: commitment.id,
            selectionTokenData: try? JSONEncoder().encode(selection),
            updatedAt: now
        )
        try? await repo.save(CommitmentSnapshot(commitment: commitment, blockSet: blockSet, keyPairing: nil))

        OnboardingFlag.setRole(.blocker)
        role = .blocker
        OnboardingFlag.setVertical(vertical)
        self.vertical = vertical
        OnboardingFlag.setComplete()
        didOnboard = true
    }

    /// Finish onboarding as an approver-only user: no Screen Time, no shield, no key, no
    /// commitment. They just hold a Supabase account and approve someone else's unlocks.
    func completeAsApprover() {
        OnboardingFlag.setRole(.approver)
        role = .approver
        OnboardingFlag.setComplete()
        didOnboard = true
    }

    /// Slice 2: reconcile the active commitment with Supabase and push it up (no-op when
    /// signed out). Loading through the composite repo writes the locked-wins result back to
    /// the cache and upserts the `commitments` row. Safe to call on launch and after sign-in.
    func syncCommitment() async {
        activeCommitment = (try? await repo.loadActiveCommitment())?.commitment
    }

    /// Tier-1: grow the gambling web blocklist from Supabase on launch (public table, no sign-in),
    /// falling back to the curated seed. Re-applies the filter immediately if currently shielded.
    func refreshBlocklist() async {
        let changed = await BlocklistService.fetchAndStore()
        if changed && SharedState.phase() == "locked" {
            shield.apply(selectionStore.load())
        }
    }

    // MARK: - Key-gated blocklist editing (FR-SHIELD-009 / FR-SHIELD-010)

    /// Shared gate for any loosening (removing a blocked app, turning off a website category):
    /// prove the physical key, then — IF a sponsor is linked — get the sponsor's approval, stacked
    /// before the cooling-off (FR-SHIELD-010, FR-P2-SPON-002/003). Returns true only when cleared
    /// to start the cooldown; any failure leaves protection in place. Tightening never calls this.
    private func approveLoosening(kind: String) async -> Bool {
        guard let paired = keyStore.load() else {
            blockChangeMessage = "Pair your key first to reduce protection."
            return false
        }
        do {
            guard case .verified(let updated) = try await security.verifyPresence(of: paired) else {
                blockChangeMessage = "That wasn't your paired key — nothing changed."
                return false
            }
            // Advance the signature counter, unless the paired key changed during the tap.
            if keyStore.load()?.credentialID == updated.credentialID { keyStore.save(updated) }
        } catch {
            blockChangeMessage = "Key check cancelled — nothing changed."
            return false
        }

        // In sponsor mode, the sponsor must approve before the cooling-off can even start.
        if isSponsorModeActive, let commitmentID = activeCommitment?.id {
            blockChangeMessage = "Sent to your sponsor for approval…"
            do {
                let requestID = try await approval.createRequest(commitmentID: commitmentID, kind: kind)
                switch await approval.pollDecision(requestID: requestID) {
                case .approved:        break
                case .denied:          blockChangeMessage = "Your sponsor denied the change."; return false
                case .expired, .failed: blockChangeMessage = "No sponsor response — change cancelled."; return false
                }
            } catch {
                blockChangeMessage = "Couldn't reach your sponsor — change cancelled."
                return false
            }
        }
        return true
    }

    /// Apply an edited block selection. Adding targets applies immediately (FR-SHIELD-009).
    /// Removing a target is a loosening: paired key + (sponsor approval if linked) + cooling-off,
    /// and the removed targets stay blocked until it all clears (FR-SHIELD-010, HC-4).
    func requestSelectionChange(_ new: FamilyActivitySelection) async {
        clearPendingSelection()                              // supersede any in-flight change
        let current = selectionStore.load()
        let removed = !current.applicationTokens.subtracting(new.applicationTokens).isEmpty
            || !current.categoryTokens.subtracting(new.categoryTokens).isEmpty
            || !current.webDomainTokens.subtracting(new.webDomainTokens).isEmpty

        guard removed else {
            // Pure addition (or no change): free + instant.
            selectionStore.save(new)
            shield.apply(new)
            blockChangeMessage = "Updated — new blocks apply right away."
            return
        }

        // A removal. First honor any adds instantly by applying the UNION (nothing dropped yet),
        // so the removed targets keep being blocked while we gate the removal.
        var union = FamilyActivitySelection()
        union.applicationTokens = current.applicationTokens.union(new.applicationTokens)
        union.categoryTokens    = current.categoryTokens.union(new.categoryTokens)
        union.webDomainTokens   = current.webDomainTokens.union(new.webDomainTokens)
        selectionStore.save(union)
        shield.apply(union)

        // Gate the removal: key, then sponsor approval if linked (FR-SHIELD-010, FR-P2-SPON-*).
        guard await approveLoosening(kind: "remove_app") else { return }

        // Cleared → wait out the cooling-off before the removal takes effect.
        let endsAt = Date().addingTimeInterval(cooldownSeconds)
        selectionChangeStore.save(PendingSelectionChange(selection: new, endsAt: endsAt))
        pendingSelectionChange = endsAt
        scheduleSelectionCommit(at: endsAt)
        blockChangeMessage = "Removal starts in \(Int(cooldownSeconds / 60)) min — they stay blocked until then."
    }

    func cancelSelectionChange() {
        let had = pendingSelectionChange != nil
        clearPendingSelection()
        if had { blockChangeMessage = "Cancelled — nothing was removed." }
    }

    /// On launch: resume a pending removal, or commit it if its wait already elapsed while the
    /// app was closed (so force-quitting can't skip the cooling-off).
    func restorePendingSelectionChange() {
        guard let p = selectionChangeStore.load() else { return }
        if Date() >= p.endsAt {
            commitSelectionChange()
        } else {
            pendingSelectionChange = p.endsAt
            scheduleSelectionCommit(at: p.endsAt)
        }
    }

    private func commitSelectionChange() {
        guard let p = selectionChangeStore.load() else { return }
        selectionStore.save(p.selection)
        shield.apply(p.selection)
        clearPendingSelection()
        blockChangeMessage = "Your changes are now applied."
    }

    private func clearPendingSelection() {
        selectionTimer?.cancel(); selectionTimer = nil
        selectionChangeStore.clear()
        pendingSelectionChange = nil
    }

    private func scheduleSelectionCommit(at endsAt: Date) {
        selectionTimer?.cancel()
        selectionTimer = Task { [weak self] in
            let delay = endsAt.timeIntervalSinceNow
            if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            if Task.isCancelled { return }
            self?.commitSelectionChange()
        }
    }

    // MARK: - Website category editing (gambling / adult), with asymmetry

    private var categoryTimer: Task<Void, Never>?
    private(set) var pendingCategoryChange: Date?

    /// Change which website categories are blocked. Turning one ON applies immediately
    /// (tightening is free); turning one OFF is removing protection — paired key + cooling-off —
    /// and it stays ON until the wait ends (FR-SHIELD-010, HC-4).
    func requestWebCategories(gambling: Bool, adult: Bool) async {
        clearPendingCategory()
        let curG = gamblingOn, curA = adultOn
        let turningOff = (curG && !gambling) || (curA && !adult)

        guard turningOff else {
            setWebCategories(gambling: gambling, adult: adult)
            blockChangeMessage = "Updated — added protection applies right away."
            return
        }

        // Keep everything currently on (plus anything newly turned on) while we gate the turn-off.
        setWebCategories(gambling: gambling || curG, adult: adult || curA)

        // Gate the turn-off: key, then sponsor approval if linked (FR-SHIELD-010, FR-P2-SPON-*).
        guard await approveLoosening(kind: "disable_category") else { return }

        let endsAt = Date().addingTimeInterval(cooldownSeconds)
        let d = UserDefaults.standard
        d.set(gambling, forKey: "pawl.pendingCat.gambling")
        d.set(adult, forKey: "pawl.pendingCat.adult")
        d.set(endsAt.timeIntervalSince1970, forKey: "pawl.pendingCat.endsAt")
        pendingCategoryChange = endsAt
        scheduleCategoryCommit(at: endsAt)
        blockChangeMessage = "Turning that off starts in \(Int(cooldownSeconds / 60)) min — it stays on until then."
    }

    func cancelCategoryChange() {
        let had = pendingCategoryChange != nil
        clearPendingCategory()
        if had { blockChangeMessage = "Cancelled — protection unchanged." }
    }

    func restorePendingCategoryChange() {
        let end = UserDefaults.standard.double(forKey: "pawl.pendingCat.endsAt")
        guard end > 0 else { return }
        let endsAt = Date(timeIntervalSince1970: end)
        if Date() >= endsAt { commitCategoryChange() }
        else { pendingCategoryChange = endsAt; scheduleCategoryCommit(at: endsAt) }
    }

    private func commitCategoryChange() {
        let d = UserDefaults.standard
        guard d.double(forKey: "pawl.pendingCat.endsAt") > 0 else { return }
        setWebCategories(gambling: d.bool(forKey: "pawl.pendingCat.gambling"),
                         adult: d.bool(forKey: "pawl.pendingCat.adult"))
        clearPendingCategory()
        blockChangeMessage = "Your changes are now applied."
    }

    private func clearPendingCategory() {
        categoryTimer?.cancel(); categoryTimer = nil
        let d = UserDefaults.standard
        d.removeObject(forKey: "pawl.pendingCat.gambling")
        d.removeObject(forKey: "pawl.pendingCat.adult")
        d.removeObject(forKey: "pawl.pendingCat.endsAt")
        pendingCategoryChange = nil
    }

    private func scheduleCategoryCommit(at endsAt: Date) {
        categoryTimer?.cancel()
        categoryTimer = Task { [weak self] in
            let delay = endsAt.timeIntervalSinceNow
            if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            if Task.isCancelled { return }
            self?.commitCategoryChange()
        }
    }

    // MARK: - Friction customization (cooldown + grace)

    /// Request new durations. Stricter (longer cooldown / shorter grace) applies immediately;
    /// looser waits out the *current* cooldown first, so there's no shortcut in the moment.
    func requestDurations(cooldown: TimeInterval, grace: TimeInterval) async {
        let cd = PawlDefaults.clampCoolingOff(cooldown)
        let gr = PawlDefaults.clampGrace(grace)
        let isTighten = cd >= cooldownSeconds && gr <= graceSeconds
        if isTighten {
            cancelPendingDurations()                       // supersede any pending loosening
            await applyDurations(cooldown: cd, grace: gr)
        } else {
            let endsAt = Date().addingTimeInterval(cooldownSeconds)
            let pending = PendingDurations(cooldown: cd, grace: gr, endsAt: endsAt)
            durationStore.save(pending)
            pendingDurations = pending
            scheduleDurationCommit(at: endsAt)
        }
    }

    func cancelPendingDurations() {
        durationTimer?.cancel(); durationTimer = nil
        durationStore.clear()
        pendingDurations = nil
    }

    /// On launch: resume a pending loosening, or commit it if its wait already elapsed.
    func restorePendingDurations() {
        guard let p = durationStore.load() else { return }
        if Date() >= p.endsAt {
            Task { await commitPendingDurations() }
        } else {
            pendingDurations = p
            scheduleDurationCommit(at: p.endsAt)
        }
    }

    private func commitPendingDurations() async {
        guard let p = durationStore.load() else { return }
        await applyDurations(cooldown: p.cooldown, grace: p.grace)
        durationStore.clear()
        pendingDurations = nil
        durationTimer?.cancel(); durationTimer = nil
    }

    private func scheduleDurationCommit(at endsAt: Date) {
        durationTimer?.cancel()
        durationTimer = Task { [weak self] in
            let delay = endsAt.timeIntervalSinceNow
            if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            if Task.isCancelled { return }
            await self?.commitPendingDurations()
        }
    }

    private func applyDurations(cooldown: TimeInterval, grace: TimeInterval) async {
        guard var snap = try? await repo.loadActiveCommitment() else { return }
        snap.commitment.coolingOffSeconds = PawlDefaults.clampCoolingOff(cooldown)
        snap.commitment.graceSeconds = PawlDefaults.clampGrace(grace)
        snap.commitment.updatedAt = Date()
        try? await repo.save(snap)
        activeCommitment = snap.commitment
    }

    /// An approver decides they want Pawl to block gambling on their own phone too. Re-runs
    /// setup; finishing it (activate) flips them to the blocker role. Their account + sponsor
    /// links are untouched, so they end up as a blocker who also sponsors. Adding protection
    /// is always free (FR-SHIELD-009 spirit).
    func setUpBlocking() {
        OnboardingFlag.reset()
        didOnboard = false
    }

    /// Dev only: run onboarding again. Does NOT erase streak/history.
    func resetOnboarding() {
        OnboardingFlag.reset()
        didOnboard = false
    }

    var blockedSummary: (apps: Int, sites: Int) {
        let s = selectionStore.load()
        return (s.applicationTokens.count + s.categoryTokens.count, s.webDomainTokens.count)
    }

    // MARK: - Phase 3 hard lock (sponsor passcode attestation — scaffolding)

    /// Mirrors the iCloud-backed attestation as observed state, so Settings reflects it live when
    /// it's set or reset. The attestation is sponsor-reported — Pawl can't verify the passcode itself.
    private(set) var hardLockAttested: Bool
    private(set) var hardLockDate: Date?

    /// The sponsor attests they set the device Screen Time passcode and verified it blocks changes.
    func attestHardLock() {
        HardLock.attest()
        hardLockAttested = true
        hardLockDate = HardLock.attestedDate()
        Task { await setServerHardLock(true) }
    }

    /// Clear the attestation so the hard lock can be set up again (e.g. it was attested by mistake
    /// or a biometric/device-passcode let a change through, so it wasn't really enforced). This only
    /// clears Pawl's record — it does NOT change the device Screen Time passcode (iOS has no API for
    /// that; the user turns it off in Settings → Screen Time if needed).
    func resetHardLock() {
        HardLock.clear()
        hardLockAttested = false
        hardLockDate = nil
        Task { await setServerHardLock(false) }
    }

    /// Record the hard-lock attestation on the server commitment (best-effort; no-op signed out),
    /// so the linked sponsor sees it and a later tamper can be flagged a breach (FR-P3-HARD-004/005).
    private func setServerHardLock(_ active: Bool) async {
        struct P: Encodable { let p_active: Bool }
        _ = try? await Supa.client.rpc("set_hard_lock", params: P(p_active: active)).execute()
    }
}

/// Records the sponsor's attestation that the device Screen Time passcode is set + verified
/// (docs/11_Phase3_Passcode.md). Stored in iCloud so it survives reinstall. Local for now;
/// server-side attestation (RPC + columns) is a later step. Pawl never holds the passcode.
enum HardLock {
    private static let key = "pawl.hardlock.attestedAt"

    @MainActor static func attest() {
        CloudStore.shared.set(Data(String(Date().timeIntervalSince1970).utf8), forKey: key)
    }
    @MainActor static func attestedDate() -> Date? {
        guard let d = CloudStore.shared.data(forKey: key),
              let s = String(data: d, encoding: .utf8),
              let ts = Double(s) else { return nil }
        return Date(timeIntervalSince1970: ts)
    }
    @MainActor static func isAttested() -> Bool { attestedDate() != nil }
    @MainActor static func clear() { CloudStore.shared.set(nil, forKey: key) }
}

/// Persists the "has onboarded" flag in iCloud so a reinstall restores protection
/// without forcing the user back through onboarding.
enum OnboardingFlag {
    private static let key = "pawl.onboarded"
    private static let roleKey = "pawl.role"
    private static let verticalKey = "pawl.vertical"
    @MainActor static func isComplete() -> Bool { CloudStore.shared.data(forKey: key) != nil }
    @MainActor static func setComplete() { CloudStore.shared.set(Data([1]), forKey: key) }
    @MainActor static func reset() { CloudStore.shared.set(nil, forKey: key) }

    @MainActor static func role() -> AppRole {
        guard let data = CloudStore.shared.data(forKey: roleKey),
              let raw = String(data: data, encoding: .utf8),
              let r = AppRole(rawValue: raw) else { return .blocker }
        return r
    }
    @MainActor static func setRole(_ r: AppRole) {
        CloudStore.shared.set(Data(r.rawValue.utf8), forKey: roleKey)
    }

    @MainActor static func vertical() -> Vertical {
        guard let data = CloudStore.shared.data(forKey: verticalKey),
              let raw = String(data: data, encoding: .utf8),
              let v = Vertical(rawValue: raw) else { return .gambling }
        return v
    }
    @MainActor static func setVertical(_ v: Vertical) {
        CloudStore.shared.set(Data(v.rawValue.utf8), forKey: verticalKey)
    }
}
