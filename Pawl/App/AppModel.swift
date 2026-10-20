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
import ManagedSettings
import DeviceActivity

/// Who this person is using Pawl as. 2.3: the approver-only role (someone who only approved
/// another person's unlocks) was removed with the ally feature, so blocker is the only role.
/// A saved "approver" is retired at launch by LegacySponsorCleanup.
enum AppRole: String { case blocker }

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
    /// Pawl Pro entitlement (StoreKit 2). Owned here so it loads at launch. 2.3: Pro covers
    /// making new scheduled sets and the weekly report.
    let pro = ProStore()
    /// The commitment lives on the phone and in the user's own iCloud (FR-PERSIST-001..003).
    /// 2.3: the Supabase layer on top of it was removed with the backend.
    private let repo: CommitmentRepository = CloudCommitmentRepository()

    /// The active commitment, exposed so the unlock flow uses its real durations.
    private(set) var activeCommitment: Commitment?

    // Friction customization. Tightening (longer cooldown / shorter grace) applies now;
    // loosening waits out the current cooldown so it can't be weakened in the moment.
    // 2.3: the pending loosening lives in a shared controller. No key gate on this path, by design.
    let pendingDurationsCtl = PendingChangeController<DurationPair>(store: DurationPair.makeStore())
    var pendingDurations: PendingDurations? { pendingDurationsCtl.pending.map { PendingDurations($0) } }

    // Key-gated blocklist editing (FR-SHIELD-010). Adding targets is free; removing one is an
    // unlock action (security key + cooling-off) and the removed targets stay blocked until then.
    private let security = SecurityKeyService()
    private let keyStore = KeyStore()
    /// 2.3: a gated removal waiting out the cooling-off. It uses the same keys the old
    /// SelectionChangeStore did (pawl.pendingSel.data and .endsAt), so a removal saved by 2.2
    /// is picked up as is. What it does when the wait ends is set in init.
    let pendingSelection = PendingChangeController<FamilyActivitySelection>(
        store: PendingChangeStore(name: "pawl.pendingSel"))
    var pendingSelectionChange: Date? { pendingSelection.endsAt }   // endsAt of a gated removal, if any
    var blockChangeMessage: String?
    var currentSelection: FamilyActivitySelection { selectionStore.load() }

    var cooldownSeconds: TimeInterval { activeCommitment?.coolingOffSeconds ?? PawlDefaults.coolingOffDefault }
    var graceSeconds: TimeInterval { activeCommitment?.graceSeconds ?? PawlDefaults.graceDefault }

    init() {
        // 2.3: quietly retire what the removed ally feature left on the phone, before any of
        // the state below is read. Never touches the shield, the key or the streak.
        LegacySponsorCleanup.run()
        didOnboard = OnboardingFlag.isComplete()
        role = OnboardingFlag.role()
        vertical = OnboardingFlag.vertical()
        hardLockAttested = HardLock.isAttested()
        hardLockDate = HardLock.attestedDate()
        customDomains = customDomainStore.load()
        scheduledSets = scheduledSetStore.load()
        // Web defaults before the launch shield re-apply runs. 2.3: gambling starts on only for
        // someone already set up with a gambling focus (a reinstall keeps their protection).
        // A new person starts with nothing on, so setup shows exactly what they pick.
        SharedState.ensureWebDefaults(domains: GamblingBlocklist.seedDomains,
                                      gamblingByDefault: didOnboard && vertical == .gambling)
        // Re-assert the uninstall block on every launch for an onboarded blocker, so it
        // survives relaunches and reinstalls (FR-P3-HARD-002). A phone that hasn't finished
        // setup is left deletable.
        if didOnboard && role == .blocker {
            shield.setDeletionBlock(true)
            shield.setClockLock(true)       // 2.1: FR-CLOCK-001, same lifecycle as the deletion block
        }

        // 2.3: what each pending change does once its wait ends. The key gate is not here; it
        // runs in the request methods before begin() is ever called.
        pendingSelection.apply = { [weak self] selection in
            guard let self else { return }
            self.selectionStore.save(selection)
            self.shield.apply(selection)
            self.blockChangeMessage = "Your changes are now applied."
        }
        pendingCategories.apply = { [weak self] categories in
            guard let self else { return }
            self.setWebCategories(gambling: categories.gambling, adult: categories.adult)
            self.blockChangeMessage = "Your changes are now applied."
        }
        pendingDurationsCtl.apply = { [weak self] pair in
            await self?.applyDurations(cooldown: pair.cooldown, grace: pair.grace)
        }
        pendingDomains.apply = { [weak self] domains in
            guard let self else { return }
            let remaining = Set(self.customDomains).subtracting(domains)
            self.customDomainStore.save(Array(remaining))
            self.customDomains = self.customDomainStore.load()
            if SharedState.phase() == "locked" { self.shield.apply(self.selectionStore.load()) }
            self.blockChangeMessage = "Your list is updated."
        }
        pendingSetsCtl.apply = { [weak self] target in
            guard let self else { return }
            self.applySets(target)
            self.blockChangeMessage = "Your sets are updated."
        }
    }

    /// Number of gambling/crypto sites currently blocked in Safari: the live App Group list (the
    /// bundled list, plus anything a pre-2.3 version downloaded), not just the bundled list.
    var webBlockCount: Int {
        max(SharedState.webBlockDomains().count, GamblingBlocklist.seedDomains.count)
    }
    /// Which website categories are blocked (chosen at onboarding; multi-select).
    var gamblingOn: Bool { SharedState.webBlockEnabled() }
    var adultOn: Bool { SharedState.webAdultFilter() }
    /// 2.3: the problem gambling help link and note show only when gambling is the focus
    /// or the gambling site list is on. The 988 line always shows.
    var showGamblingHelp: Bool { vertical == .gambling || gamblingOn }
    /// 2.3: the slip flow asks "Did it cost anything?" only for a gambling or shopping focus,
    /// or when the gambling site list is on. There is no shopping site category to check.
    var asksSlipCost: Bool { vertical == .gambling || vertical == .shopping || gamblingOn }

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
        SharedState.ensureWebDefaults(domains: GamblingBlocklist.seedDomains,
                                      gamblingByDefault: didOnboard && vertical == .gambling)
        shield.apply(selectionStore.load())
        if role == .blocker {
            shield.setDeletionBlock(true)
            shield.setClockLock(true)       // 2.1: FR-CLOCK-001
        }
    }

    /// Finish onboarding: persist the selection, apply the shield, create the commitment
    /// (FR-ONBOARD-003, FR-SHIELD-005). Streak starts now.
    func activate(selection: FamilyActivitySelection, vertical: Vertical = .gambling) async {
        // 2.1: if this phone was already protecting (setup shown again, e.g. after the iCloud
        // "onboarded" flag went missing), setup may only ADD protection: keep every block that
        // was on, keep the existing commitment and its durations and streak (HC-4).
        let existing: Commitment?
        if let active = activeCommitment {
            existing = active
        } else {
            existing = (try? await repo.loadActiveCommitment())?.commitment
        }
        let previous = SharedState.loadSelection()
        var selection = selection
        if setupWasAlreadyProtecting || existing != nil {
            selection.applicationTokens = selection.applicationTokens.union(previous.applicationTokens)
            selection.categoryTokens    = selection.categoryTokens.union(previous.categoryTokens)
            selection.webDomainTokens   = selection.webDomainTokens.union(previous.webDomainTokens)
        }
        selectionStore.save(selection)
        shield.apply(selection)
        shield.setDeletionBlock(true)   // Pawl can't be uninstalled while protecting (FR-P3-HARD-002)
        shield.setClockLock(true)       // 2.1: the clock can't be moved forward to skip the wait (FR-CLOCK-001)

        let now = Date()
        let commitment = existing ?? Commitment(startedAt: now, updatedAt: now)
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

    /// Set once when setup appears, BEFORE a key can be paired in it: was this phone or account
    /// already protecting someone (a paired key, an active commitment, or a saved block list)?
    /// Then setup may only tighten (2.1).
    private(set) var setupWasAlreadyProtecting = false

    func noteSetupStarted() async {
        let previous = SharedState.loadSelection()
        let hadSelection = !previous.applicationTokens.isEmpty || !previous.categoryTokens.isEmpty
            || !previous.webDomainTokens.isEmpty
        var existing = activeCommitment
        if existing == nil { existing = (try? await repo.loadActiveCommitment())?.commitment }
        setupWasAlreadyProtecting = existing != nil || keyStore.state() != .unpaired || hadSelection
    }

    /// Website categories chosen during setup. On a first setup they apply as picked. If setup
    /// runs again on a phone that was already protecting, a category that was on stays on;
    /// turning it off is the gated path in Settings.
    func setOnboardingWebCategories(gambling: Bool, adult: Bool) {
        if setupWasAlreadyProtecting {
            setWebCategories(gambling: gambling || gamblingOn, adult: adult || adultOn)
        } else {
            setWebCategories(gambling: gambling, adult: adult)
        }
    }

    /// Load the active commitment from the phone and iCloud. Safe to call on every launch.
    func loadCommitment() async {
        activeCommitment = (try? await repo.loadActiveCommitment())?.commitment
    }

    // MARK: - Key-gated blocklist editing (FR-SHIELD-009 / FR-SHIELD-010)

    /// Shared gate for any loosening (removing a blocked app, turning off a website category):
    /// prove the physical key (FR-SHIELD-010). Returns true only when cleared to start the
    /// cooldown; any failure leaves protection in place. Tightening never calls this.
    /// 2.3: the ally approval step that used to follow the key was removed with the backend.
    private func approveLoosening() async -> Bool {
        guard let paired = keyStore.load() else {
            blockChangeMessage = "Pair your key first to reduce protection."
            return false
        }
        do {
            guard case .verified(let updated) = try await security.verifyPresence(of: paired) else {
                blockChangeMessage = "That wasn't your paired key. Nothing changed."
                return false
            }
            // Advance the signature counter, unless the paired key changed during the tap.
            if keyStore.load()?.credentialID == updated.credentialID { keyStore.save(updated) }
        } catch {
            blockChangeMessage = "Key check cancelled. Nothing changed."
            return false
        }
        return true
    }

    /// Apply an edited block selection. Adding targets applies immediately (FR-SHIELD-009).
    /// Removing a target is a loosening: paired key + cooling-off,
    /// and the removed targets stay blocked until it all clears (FR-SHIELD-010, HC-4).
    func requestSelectionChange(_ new: FamilyActivitySelection) async {
        pendingSelection.clear()                             // supersede any in-flight change
        let current = selectionStore.load()
        let removed = !current.applicationTokens.subtracting(new.applicationTokens).isEmpty
            || !current.categoryTokens.subtracting(new.categoryTokens).isEmpty
            || !current.webDomainTokens.subtracting(new.webDomainTokens).isEmpty

        guard removed else {
            // Pure addition (or no change): free + instant.
            selectionStore.save(new)
            shield.apply(new)
            blockChangeMessage = "Updated. New blocks apply right away."
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

        // Gate the removal with the key (FR-SHIELD-010).
        guard await approveLoosening() else { return }

        // Cleared → wait out the cooling-off before the removal takes effect.
        let endsAt = Date().addingTimeInterval(cooldownSeconds)
        pendingSelection.begin(new, endsAt: endsAt)
        blockChangeMessage = "Removal starts in \(Int(cooldownSeconds / 60)) min. They stay blocked until then."
    }

    func cancelSelectionChange() {
        let had = pendingSelectionChange != nil
        pendingSelection.clear()
        if had { blockChangeMessage = "Cancelled. Nothing was removed." }
    }

    /// On launch: resume a pending removal, or commit it if its wait already elapsed while the
    /// app was closed (so force-quitting can't skip the cooling-off).
    func restorePendingSelectionChange() async {
        await pendingSelection.restore()
    }

    // MARK: - Website category editing (gambling / adult), with asymmetry

    /// 2.3: a gated category turn-off waiting out the cooling-off. Moved off the three raw
    /// pawl.pendingCat.* keys; a turn-off saved by 2.2 is moved over with its exact end time.
    let pendingCategories = PendingChangeController<WebCategories>(store: WebCategories.makeStore())
    var pendingCategoryChange: Date? { pendingCategories.endsAt }

    // 2.2: the user's own typed website list (FR-SHIELD-003/004). Adding is instant;
    // removing is gated exactly like removing an app or a category (FR-SHIELD-010).
    private let customDomainStore = CustomDomainStore()
    let pendingDomains = PendingChangeController<[String]>(store: CustomDomainStore.makePendingStore())
    var pendingDomainRemoval: CustomDomainStore.PendingRemoval? {
        pendingDomains.pending.map { CustomDomainStore.PendingRemoval(domains: $0.payload, endsAt: $0.endsAt) }
    }
    /// Mirrors the stored list so SwiftUI sees changes (a computed read of UserDefaults would not).
    private(set) var customDomains: [String] = []

    // 2.2: scheduled block sets. The pre-2.2 selection is the "Always on" set and keeps its own
    // gating above. Adding a set or tightening one applies now; loosening (fewer apps, fewer
    // hours, off, deleted) is gated like every other removal (FR-SHIELD-010).
    private let scheduledSetStore = ScheduledSetStore()
    let pendingSetsCtl = PendingChangeController<[ScheduledSet]>(store: ScheduledSetStore.makePendingStore())
    var pendingSets: ScheduledSetStore.PendingSets? {
        pendingSetsCtl.pending.map { ScheduledSetStore.PendingSets(target: $0.payload, endsAt: $0.endsAt) }
    }
    private(set) var scheduledSets: [ScheduledSet] = []

    /// Change which website categories are blocked. Turning one ON applies immediately
    /// (tightening is free); turning one OFF is removing protection — paired key + cooling-off —
    /// and it stays ON until the wait ends (FR-SHIELD-010, HC-4).
    func requestWebCategories(gambling: Bool, adult: Bool) async {
        pendingCategories.clear()
        let curG = gamblingOn, curA = adultOn
        let turningOff = (curG && !gambling) || (curA && !adult)

        guard turningOff else {
            setWebCategories(gambling: gambling, adult: adult)
            blockChangeMessage = "Updated. Added protection applies right away."
            return
        }

        // Keep everything currently on (plus anything newly turned on) while we gate the turn-off.
        setWebCategories(gambling: gambling || curG, adult: adult || curA)

        // Gate the turn-off with the key (FR-SHIELD-010).
        guard await approveLoosening() else { return }

        let endsAt = Date().addingTimeInterval(cooldownSeconds)
        pendingCategories.begin(WebCategories(gambling: gambling, adult: adult), endsAt: endsAt)
        blockChangeMessage = "Turning that off starts in \(Int(cooldownSeconds / 60)) min. It stays on until then."
    }

    func cancelCategoryChange() {
        let had = pendingCategoryChange != nil
        pendingCategories.clear()
        if had { blockChangeMessage = "Cancelled. Protection unchanged." }
    }

    func restorePendingCategoryChange() async {
        await pendingCategories.restore()
    }

    // MARK: - Typed website list (2.2, FR-SHIELD-003/004)

    /// Add one or more sites from free text: one per line, or separated by commas or spaces.
    /// Returns how many new sites were added. Adding only ever tightens, so it applies now.
    @discardableResult
    func addCustomDomains(_ text: String) -> Int {
        let parts = text.split(whereSeparator: { $0 == "\n" || $0 == "," || $0 == " " }).map(String.init)
        let cleaned = Set(parts.compactMap(BlocklistService.cleanHostname))
        guard !cleaned.isEmpty else {
            blockChangeMessage = "That doesn't look like a website address. Try something like example.com."
            return 0
        }
        let before = Set(customDomains)
        let added = cleaned.subtracting(before)
        guard !added.isEmpty else {
            blockChangeMessage = "Already on your list."
            return 0
        }
        if before.count + added.count > CustomDomainStore.maxDomains {
            blockChangeMessage = "Your list is full (\(CustomDomainStore.maxDomains) sites)."
            return 0
        }
        customDomainStore.save(Array(before.union(added)))
        customDomains = customDomainStore.load()
        if SharedState.phase() == "locked" { shield.apply(selectionStore.load()) }
        blockChangeMessage = added.count == 1
            ? "Added. It's blocked right away."
            : "Added \(added.count) sites. They're blocked right away."
        return added.count
    }

    /// Ask to drop sites from the list. Needs the key, then the cooldown; the sites stay
    /// blocked until the wait ends (FR-SHIELD-010, HC-4).
    func requestRemoveCustomDomains(_ domains: [String]) async {
        let targets = Set(domains).intersection(customDomains)
        guard !targets.isEmpty else { return }
        pendingDomains.clear()

        guard await approveLoosening() else { return }

        let endsAt = Date().addingTimeInterval(cooldownSeconds)
        pendingDomains.begin(Array(targets).sorted(), endsAt: endsAt)
        blockChangeMessage = targets.count == 1
            ? "Removal starts in \(Int(cooldownSeconds / 60)) min. The site stays blocked until then."
            : "Removal starts in \(Int(cooldownSeconds / 60)) min. The sites stay blocked until then."
    }

    func cancelDomainRemoval() {
        let had = pendingDomainRemoval != nil
        pendingDomains.clear()
        if had { blockChangeMessage = "Cancelled. Your list is unchanged." }
    }

    /// On launch: pull the iCloud mirror back after a reinstall, then resume or finish a wait.
    func restorePendingDomainRemoval() async {
        customDomainStore.restoreFromCloudIfNeeded()
        customDomains = customDomainStore.load()
        await pendingDomains.restore()
    }

    // MARK: - Time kept (2.2)

    private static let hoursPerDayKey = "pawl.hoursPerDay"

    /// The setup answer to "about how many hours a day go to this?". On the phone only, used
    /// for the hours-kept lines on Home and the tough-moment screen. 0 means not answered.
    var hoursPerDay: Double {
        get { UserDefaults.standard.double(forKey: Self.hoursPerDayKey) }
        set { UserDefaults.standard.set(max(0, newValue), forKey: Self.hoursPerDayKey) }
    }

    // MARK: - Scheduled block sets (2.2)

    /// One short line for Home and Settings, for example "Gambling · 3 apps · 2 sites · 1 set".
    var blockedSummaryLine: String {
        let parts = blockedSummaryParts
        return parts.isEmpty ? "Nothing yet" : parts.joined(separator: " · ")
    }

    /// 2.3: the same pieces as a list, so Home can show them as chips.
    var blockedSummaryParts: [String] {
        var parts: [String] = []
        if gamblingOn { parts.append("Gambling") }
        if adultOn { parts.append("Adult") }
        let s = blockedSummary
        if s.apps > 0 { parts.append(s.apps == 1 ? "1 app" : "\(s.apps) apps") }
        let sites = s.sites + customDomains.count
        if sites > 0 { parts.append(sites == 1 ? "1 site" : "\(sites) sites") }
        let sets = scheduledSets.count
        if sets > 0 { parts.append(sets == 1 ? "1 set" : "\(sets) sets") }
        return parts
    }

    /// Name of a scheduled set whose window is open right now, if any.
    var activeScheduledSetName: String? {
        let now = Date()
        return scheduledSets.first { $0.isActive(at: now) }?.name
    }


    /// Save a new or edited set. Tightening applies now; loosening keeps the old set in place,
    /// then needs the key and the cooldown before the new one lands.
    func saveScheduledSet(_ set: ScheduledSet) async {
        var target = scheduledSets
        if let i = target.firstIndex(where: { $0.id == set.id }) {
            let old = target[i]
            target[i] = set
            if ScheduledSet.isLoosening(old: old, new: set) {
                await gateSetsChange(target, what: "That change blocks less, so it waits.")
                return
            }
        } else {
            // 2.3: making a new set is a Pro feature. Sets made before keep running, and
            // editing or deleting one never needs Pro. The views send people to the paywall
            // first; this is the backstop.
            guard pro.isPro else {
                blockChangeMessage = "New scheduled sets come with Pawl Pro."
                return
            }
            guard target.count < ScheduledSet.maxSets else {
                blockChangeMessage = "You can have up to \(ScheduledSet.maxSets) sets."
                return
            }
            target.append(set)
        }
        applySets(target)
        blockChangeMessage = "Saved. It's in effect whenever its schedule is on."
    }

    /// Deleting always blocks less, so it is always gated.
    func requestDeleteScheduledSet(_ set: ScheduledSet) async {
        let target = scheduledSets.filter { $0.id != set.id }
        guard target.count != scheduledSets.count else { return }
        await gateSetsChange(target, what: "Deleting a set blocks less, so it waits.")
    }

    func cancelSetsChange() {
        let had = pendingSets != nil
        pendingSetsCtl.clear()
        if had { blockChangeMessage = "Cancelled. Your sets are unchanged." }
    }

    /// On launch: pull the iCloud mirror back after a reinstall, re-register the schedules, then
    /// resume or finish a wait.
    func restorePendingSetsChange() async {
        scheduledSetStore.restoreFromCloudIfNeeded()
        scheduledSets = scheduledSetStore.load()
        await pendingSetsCtl.restore()
    }

    private func gateSetsChange(_ target: [ScheduledSet], what: String) async {
        pendingSetsCtl.clear()
        guard await approveLoosening() else { return }
        let endsAt = Date().addingTimeInterval(cooldownSeconds)
        pendingSetsCtl.begin(target, endsAt: endsAt)
        blockChangeMessage = "\(what) It applies in \(Int(cooldownSeconds / 60)) min."
    }

    private func applySets(_ sets: [ScheduledSet]) {
        scheduledSetStore.save(sets)
        scheduledSets = sets
        if SharedState.phase() == "locked" { shield.apply(selectionStore.load()) }
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
            pendingDurationsCtl.begin(DurationPair(cooldown: cd, grace: gr), endsAt: endsAt)
        }
    }

    func cancelPendingDurations() {
        pendingDurationsCtl.clear()
    }

    /// On launch: resume a pending loosening, or commit it if its wait already elapsed.
    /// 2.3: awaited like the other four, so an expired loosening is applied before the next
    /// restore starts (it used to commit in a detached Task).
    func restorePendingDurations() async {
        await pendingDurationsCtl.restore()
    }

    private func applyDurations(cooldown: TimeInterval, grace: TimeInterval) async {
        guard var snap = try? await repo.loadActiveCommitment() else { return }
        snap.commitment.coolingOffSeconds = PawlDefaults.clampCoolingOff(cooldown)
        snap.commitment.graceSeconds = PawlDefaults.clampGrace(grace)
        snap.commitment.updatedAt = Date()
        try? await repo.save(snap)
        activeCommitment = snap.commitment
    }

    /// Dev only: run onboarding again. Does NOT erase streak/history.
    func resetOnboarding() {
        OnboardingFlag.reset()
        didOnboard = false
    }

    #if DEBUG
    /// DEV ONLY (Xcode Debug builds). Erases every piece of Pawl state on this phone and in its
    /// iCloud copy, lifts every restriction, then closes the app so the next launch is a true
    /// first run. Never compiled into Release: in the App Store build this would be exactly the
    /// escape hatch Pawl exists to remove.
    func devEraseEverything() {
        // Restrictions first, so nothing stays blocked: shields, website filter, app-deletion
        // block, the clock lock, and every scheduled window.
        ManagedSettingsStore(named: .pawl).clearAllSettings()
        DeviceActivityCenter().stopMonitoring()
        UnlockReminders.cancel()   // and any unlock reminders still waiting
        // The paired key (Keychain), including a re-pair that is waiting.
        keyStore.clearPending()
        keyStore.clear()
        // The iCloud key-value copy: commitment, streak, logs, onboarding flags, sets, typed
        // sites, the saved selection, the hard lock, the person to call.
        let kv = NSUbiquitousKeyValueStore.default
        for key in kv.dictionaryRepresentation.keys { kv.removeObject(forKey: key) }
        kv.synchronize()
        // The App Group (shared with the extensions) and the app's own settings: pending waits,
        // web categories, attempts, Pro cache, review-prompt clock, hours per day.
        UserDefaults(suiteName: AppGroup.id)?.removePersistentDomain(forName: AppGroup.id)
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        exit(0)
    }
    #endif

    var blockedSummary: (apps: Int, sites: Int) {
        let s = selectionStore.load()
        return (s.applicationTokens.count + s.categoryTokens.count, s.webDomainTokens.count)
    }

    // MARK: - Hard lock (a trusted person sets the Screen Time passcode)

    /// Mirrors the iCloud-backed attestation as observed state, so Settings reflects it live when
    /// it's set or reset. The attestation is self-reported; Pawl can't verify the passcode itself.
    /// 2.3: on the phone and iCloud only. The server copy went away with the backend.
    private(set) var hardLockAttested: Bool
    private(set) var hardLockDate: Date?

    /// The trusted person attests they set the device Screen Time passcode and verified it blocks changes.
    func attestHardLock() {
        HardLock.attest()
        hardLockAttested = true
        hardLockDate = HardLock.attestedDate()
    }

    /// Clear the attestation so the hard lock can be set up again (e.g. it was attested by mistake
    /// or a biometric/device-passcode let a change through, so it wasn't really enforced). This only
    /// clears Pawl's record — it does NOT change the device Screen Time passcode (iOS has no API for
    /// that; the user turns it off in Settings → Screen Time if needed).
    func resetHardLock() {
        HardLock.clear()
        hardLockAttested = false
        hardLockDate = nil
    }
}

/// Records a trusted person's attestation that the device Screen Time passcode is set + verified
/// (docs/archive/11_Phase3_Passcode.md). Stored in iCloud so it survives reinstall. Pawl never
/// holds the passcode.
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

    /// 2.3: the approver-only role was removed with the ally feature. Someone who only approved
    /// for others has nothing set up to block, so they go through setup next launch. Their
    /// streak and history are untouched. Returns true if a saved approver role was retired.
    @MainActor @discardableResult static func retireApproverRole() -> Bool {
        guard let data = CloudStore.shared.data(forKey: roleKey),
              String(data: data, encoding: .utf8) == "approver" else { return false }
        setRole(.blocker)
        reset()
        return true
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
