// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  Models.swift
//  Pawl — Domain core
//
//  Pure, platform-agnostic value types for the Phase 1 data model (SDS §3.1).
//  These types carry NO FamilyControls / ManagedSettings imports on purpose:
//  the domain layer never resolves app identities — selection lives as an opaque
//  archived blob (HC-1, SRS NFR-PRIV-001/002). The iOS layer archives/unarchives
//  a `FamilyActivitySelection` into `BlockSet.selectionTokenData`.
//

import Foundation

// MARK: - Tunables / defaults (SRS §3.4)

public enum PawlDefaults {
    /// Mandatory cooling-off floor: tap + wait before the shield lifts (FR-UNLOCK-003/004).
    public static let coolingOffFloor: TimeInterval = 15 * 60        // 15 minutes
    /// Default cooling-off duration (user may raise, never lower below the floor).
    public static let coolingOffDefault: TimeInterval = 15 * 60
    /// Bounded grace window after the shield lifts, before auto-relock (FR-UNLOCK-008).
    /// Kept modest — long enough to be usable, short enough to limit damage. Also stays at or above
    /// the ~15-min DeviceActivity window minimum so the durable auto-relock fires reliably.
    /// Shorter is "stricter"; the user may lengthen it only via the gated path.
    public static let graceDefault: TimeInterval = 30 * 60           // 30 minutes
    /// Floor on the grace window so it can't be set to effectively nothing by accident.
    public static let graceFloor: TimeInterval = 60                  // 1 minute
    /// Ceiling on the grace window (Decision D6). Generous enough for a real distraction-app
    /// session (e.g. a longer TikTok window), bounded so it can never be "open all evening."
    /// Default stays short (graceDefault); lengthening toward this cap is a gated loosening.
    public static let graceCeiling: TimeInterval = 3 * 60 * 60       // 3 hours

    /// Clamp a requested cooling-off duration to the enforced floor (FR-UNLOCK-004).
    public static func clampCoolingOff(_ requested: TimeInterval) -> TimeInterval {
        max(requested, coolingOffFloor)
    }
    /// Clamp a requested grace window between its floor and ceiling (Decision D6).
    public static func clampGrace(_ requested: TimeInterval) -> TimeInterval {
        min(max(requested, graceFloor), graceCeiling)
    }
}

// MARK: - Commitment (SDS §3.1)

public enum CommitmentStatus: String, Codable, Sendable {
    case active
    case inactive
}

/// One active commitment per user in Phase 1.
public struct Commitment: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var status: CommitmentStatus
    public var startedAt: Date
    /// Seconds the user must wait after a valid tap before the shield lifts.
    public var coolingOffSeconds: TimeInterval
    /// Seconds the shield stays lifted before auto-relock.
    public var graceSeconds: TimeInterval
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        status: CommitmentStatus = .active,
        startedAt: Date,
        coolingOffSeconds: TimeInterval = PawlDefaults.coolingOffDefault,
        graceSeconds: TimeInterval = PawlDefaults.graceDefault,
        updatedAt: Date
    ) {
        self.id = id
        self.status = status
        self.startedAt = startedAt
        self.coolingOffSeconds = PawlDefaults.clampCoolingOff(coolingOffSeconds)
        self.graceSeconds = PawlDefaults.clampGrace(graceSeconds)
        self.updatedAt = updatedAt
    }
}

// MARK: - BlockSet (SDS §3.1; HC-1)

/// The user's shield targets. `selectionTokenData` is an opaque archived
/// `FamilyActivitySelection` — the domain never inspects it (HC-1).
public struct BlockSet: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var commitmentID: UUID
    public var selectionTokenData: Data?
    public var webDomains: [String]
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        commitmentID: UUID,
        selectionTokenData: Data? = nil,
        webDomains: [String] = [],
        updatedAt: Date
    ) {
        self.id = id
        self.commitmentID = commitmentID
        self.selectionTokenData = selectionTokenData
        self.webDomains = webDomains
        self.updatedAt = updatedAt
    }
}

// MARK: - KeyPairing (SDS §3.1; HC-5, HC-7)

/// One active physical NFC key per commitment. Authorization factor is a UID
/// match — not cryptographic (HC-7, NFR-SEC-002); the real control is physical
/// placement of the tag (A-2).
public struct KeyPairing: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var commitmentID: UUID
    public var tagUID: String
    public var pairedAt: Date
    /// Recorded when the "place the key out of reach" instruction was shown.
    /// We never claim to verify actual placement (FR-NFC-005, A-2).
    public var placementInstructionShownAt: Date?

    public init(
        id: UUID = UUID(),
        commitmentID: UUID,
        tagUID: String,
        pairedAt: Date,
        placementInstructionShownAt: Date? = nil
    ) {
        self.id = id
        self.commitmentID = commitmentID
        self.tagUID = tagUID
        self.pairedAt = pairedAt
        self.placementInstructionShownAt = placementInstructionShownAt
    }

    /// Constant-time-ish UID comparison used to gate an unlock (FR-UNLOCK-002).
    public func matches(_ uid: String) -> Bool {
        // Normalise case/whitespace; UIDs are hex strings.
        tagUID.lowercased() == uid.lowercased()
    }
}

// MARK: - UnlockRequest (SDS §3.1; FR-UNLOCK-011)

public enum TapResult: String, Codable, Sendable {
    case accepted
    case rejectedMismatch
    case rejectedNoTag
    case failed
}

public enum UnlockOutcome: String, Codable, Sendable {
    case pending
    case cancelled
    case completed   // cooling-off elapsed, shield lifted
    case expired     // grace ended, shield re-applied
}

/// One row per unlock attempt — the relapse/insight history (FR-UNLOCK-011).
public struct UnlockRequest: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var commitmentID: UUID
    public var requestedAt: Date
    public var tapResult: TapResult
    public var coolingOffStartedAt: Date?
    public var coolingOffEndsAt: Date?
    public var graceEndsAt: Date?
    public var completedAt: Date?
    public var cancelledAt: Date?
    public var outcome: UnlockOutcome

    public init(
        id: UUID = UUID(),
        commitmentID: UUID,
        requestedAt: Date,
        tapResult: TapResult = .failed,
        coolingOffStartedAt: Date? = nil,
        coolingOffEndsAt: Date? = nil,
        graceEndsAt: Date? = nil,
        completedAt: Date? = nil,
        cancelledAt: Date? = nil,
        outcome: UnlockOutcome = .pending
    ) {
        self.id = id
        self.commitmentID = commitmentID
        self.requestedAt = requestedAt
        self.tapResult = tapResult
        self.coolingOffStartedAt = coolingOffStartedAt
        self.coolingOffEndsAt = coolingOffEndsAt
        self.graceEndsAt = graceEndsAt
        self.completedAt = completedAt
        self.cancelledAt = cancelledAt
        self.outcome = outcome
    }
}

// MARK: - RelapseEvent / UrgeEvent (SDS §3.1; FR-STREAK, FR-URGE)

public struct RelapseEvent: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var commitmentID: UUID
    public var occurredAt: Date
    public var note: String?
    public var amount: Decimal?

    public init(id: UUID = UUID(), commitmentID: UUID, occurredAt: Date, note: String? = nil, amount: Decimal? = nil) {
        self.id = id
        self.commitmentID = commitmentID
        self.occurredAt = occurredAt
        self.note = note
        self.amount = amount
    }
}

public struct UrgeEvent: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var commitmentID: UUID
    public var occurredAt: Date
    /// 1...10, optional.
    public var intensity: Int?
    public var trigger: String?
    public var note: String?

    public init(id: UUID = UUID(), commitmentID: UUID, occurredAt: Date, intensity: Int? = nil, trigger: String? = nil, note: String? = nil) {
        self.id = id
        self.commitmentID = commitmentID
        self.occurredAt = occurredAt
        self.intensity = intensity
        self.trigger = trigger
        self.note = note
    }
}

// MARK: - Vertical (what the user is here to quit) — drives onboarding defaults + copy

/// The user's primary focus. Pawl's mechanism (shield + physical key + cooling-off) is general,
/// so the same loop serves several compulsions; the vertical only tailors defaults and wording —
/// it is NOT a different enforcement path. Gambling stays the flagship (Decision D6); adult content
/// and a custom "specific apps" focus broaden Pawl to consumers beyond gamblers. Pure data, no iOS
/// imports, so it stays in the testable domain core (HC-1 boundary).
public enum Vertical: String, Codable, Sendable, CaseIterable {
    case gambling
    case adultContent
    case custom

    /// Website categories switched on by default for this focus at onboarding. `gambling` blocks
    /// our curated domain list; `adult` turns on Apple's built-in "Limit Adult Websites" filter
    /// (we deliberately don't ship our own porn-domain list — Apple's filter is comprehensive and
    /// keeps us out of hosting that content). Custom blocks apps only until the user adds categories.
    public var defaultBlockGambling: Bool { self == .gambling }
    public var defaultBlockAdult: Bool { self == .adultContent }

    /// Short label for the focus card and Settings.
    public var title: String {
        switch self {
        case .gambling:     return "Quit gambling"
        case .adultContent: return "Filter Adult Content"
        case .custom:       return "Block distracting apps"
        }
    }

    /// One-line subtitle shown on the focus card.
    public var cardSubtitle: String {
        switch self {
        case .gambling:     return "Sportsbook, casino, and crypto apps and sites."
        case .adultContent: return "Turn on Apple's adult-site filter, and lock the apps."
        case .custom:       return "Social, games, anything you keep reaching for."
        }
    }

    /// SF Symbol for the focus card.
    public var icon: String {
        switch self {
        case .gambling:     return "dice"
        case .adultContent: return "eye.slash"
        case .custom:       return "apps.iphone"
        }
    }

    /// Welcome subtitle, tailored to the focus (keeps the physical-friction promise identical).
    public var welcomeBody: String {
        let what: String
        switch self {
        case .gambling:     what = "gambling apps and sites"
        case .adultContent: what = "adult sites and the apps you choose"
        case .custom:       what = "the apps you choose"
        }
        return "Pawl blocks \(what), and makes unblocking deliberately hard — it takes your physical security key plus a 15-minute wait. No shortcuts in the moment."
    }
}
