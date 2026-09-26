// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  ApprovalsView.swift
//  Pawl — sponsor action center (its own tab)
//
//  Where a sponsor sees and acts on unlock requests and protection alerts for the people they
//  support. Polls while visible (no APNs needed); push just makes it instant.
//
//  Protection alerts are grouped per person + kind, so repeated detections collapse into a single
//  row. An alert that the system has seen recover (Screen Time back on / app beating again) is
//  flagged "back to normal" but kept visible; the sponsor clears it with a swipe once they've
//  followed up.
//

import SwiftUI

struct ApprovalsView: View {
    let approval: UnlockApprovalService

    var body: some View {
        NavigationStack {
            List {
                if approval.sponsorPending.isEmpty && alertGroups.isEmpty {
                    emptyState
                }
                if !approval.sponsorPending.isEmpty {
                    requestsSection
                }
                if !alertGroups.isEmpty {
                    alertsSection
                }
                if !approval.sponsoredProtection.isEmpty {
                    protectionStatusSection
                }
                if let message = approval.message {
                    Section { Text(message).font(.footnote).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("Approvals")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                while !Task.isCancelled {
                    await approval.refreshSponsorPending()
                    await approval.refreshSponsorTamper()
                    await approval.refreshSponsoredProtection()
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                }
            }
        }
    }

    // MARK: - Sections

    private var emptyState: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("You're all caught up").font(.headline)
                Text("When someone you sponsor asks to unlock — or their protection drops — it shows up here. Keep notifications on so you don't miss one.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var requestsSection: some View {
        Section("Requests to approve") {
            ForEach(approval.sponsorPending) { req in
                VStack(alignment: .leading, spacing: 8) {
                    Text(title(for: req)).font(.headline)
                    Text(subtitle(for: req))
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(req.requested_at, format: .relative(presentation: .named))
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Approve") {
                            Task { await approval.decide(req, approved: true) }
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Deny", role: .destructive) {
                            Task { await approval.decide(req, approved: false) }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var alertsSection: some View {
        Section {
            ForEach(alertGroups) { group in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: groupIcon(group))
                        .font(.title3)
                        .foregroundStyle(groupColor(group))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(alertTitle(group.kind))
                            .font(.subheadline.weight(.semibold))
                        if group.breach {
                            Text("Hard lock breached — protection shouldn't have dropped")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red)
                        }
                        HStack(spacing: 6) {
                            Text(approval.name(forUser: group.userID))
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            Text("·")
                            if group.recovered && !group.breach {
                                Text("Back to normal").foregroundStyle(.green)
                                Text("·")
                            }
                            Text(group.latest, format: .relative(presentation: .named))
                            if !group.recovered && group.count > 1 {
                                Text("· \(group.count) times")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        Task { for id in group.alertIDs { await approval.resolveTamper(id: id) } }
                    } label: {
                        Label("Clear", systemImage: "checkmark")
                    }
                    .tint(.green)
                }
            }
        } header: {
            Text("Protection alerts")
        } footer: {
            Text("Pawl detects tampering after the fact — it can't prevent someone deleting the app or disabling Screen Time. Swipe an alert to clear it once you've followed up.")
        }
    }

    // MARK: - Who you sponsor (hard-lock status overview)

    private var protectionStatusSection: some View {
        Section("Who you sponsor") {
            ForEach(approval.sponsoredProtection) { p in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: p.hardLockActive ? "lock.shield.fill" : "lock.open")
                        .font(.title3)
                        .foregroundStyle(p.hardLockActive ? .green : .secondary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(p.name).font(.subheadline.weight(.semibold))
                        if p.hardLockActive {
                            Text(hardLockDetail(p))
                                .font(.caption).foregroundStyle(.green)
                        } else {
                            Text("Hard lock off — they can still disable Screen Time")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func hardLockDetail(_ p: UnlockApprovalService.ProtectionStatus) -> String {
        guard let at = p.attestedAt else { return "Hard lock on" }
        return "Hard lock on · set \(at.formatted(.dateTime.month().day().year()))"
    }

    // MARK: - Grouped alerts (collapse duplicates per person + kind)

    private struct AlertGroup: Identifiable {
        let id: String          // "userID|kind"
        let userID: String
        let kind: String
        let count: Int
        let latest: Date
        let recovered: Bool     // every alert in the group has been seen to recover
        let breach: Bool        // fired while the commitment was hard-locked → high priority
        let alertIDs: [String]
    }

    /// One row per (person, kind). Active alerts sort above recovered ones; clearing a row resolves
    /// every alert it represents.
    private var alertGroups: [AlertGroup] {
        Dictionary(grouping: approval.sponsorTamper) { "\($0.user_id.lowercased())|\($0.kind)" }
            .map { key, items in
                AlertGroup(id: key,
                           userID: items.first?.user_id ?? "",
                           kind: items.first?.kind ?? "silence",
                           count: items.count,
                           latest: items.map(\.detected_at).max() ?? Date(),
                           recovered: items.allSatisfy { $0.recovered_at != nil },
                           breach: items.contains { $0.hard_locked },
                           alertIDs: items.map(\.id))
            }
            .sorted {
                if $0.breach != $1.breach { return $0.breach }              // breaches first
                if $0.recovered != $1.recovered { return !$0.recovered }    // then still-active
                return $0.latest > $1.latest
            }
    }

    private func alertTitle(_ kind: String) -> String {
        kind == "auth_lost" ? "Screen Time was turned off" : "App went silent — may be deleted"
    }

    private func alertColor(_ kind: String) -> Color {
        kind == "auth_lost" ? .red : .orange
    }

    private func groupIcon(_ g: AlertGroup) -> String {
        if g.breach { return "exclamationmark.octagon.fill" }
        if g.recovered { return "checkmark.circle.fill" }
        return "exclamationmark.triangle.fill"
    }

    private func groupColor(_ g: AlertGroup) -> Color {
        if g.breach { return .red }
        if g.recovered { return .green }
        return alertColor(g.kind)
    }

    // MARK: - Pending request labels

    /// Who's asking — falls back to a neutral label if no display name is shared.
    private func requesterName(_ req: UnlockApprovalService.PendingRequest) -> String {
        approval.name(forUser: req.user_id)
    }

    private func title(for req: UnlockApprovalService.PendingRequest) -> String {
        "\(requesterName(req)) wants to:"
    }

    /// What exactly they're requesting (FR-P2-SPON-008) — never exposes the private journal.
    private func subtitle(for req: UnlockApprovalService.PendingRequest) -> String {
        switch req.kind {
        case "remove_app":        return "Remove a blocked app"
        case "disable_category":  return "Turn off a website filter"
        default:                  return "Unlock the shield"
        }
    }
}
