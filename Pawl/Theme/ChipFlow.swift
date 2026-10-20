// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  ChipFlow.swift
//  Pawl, Theme (2.3)
//
//  Lays chips out left to right and wraps to a new line when the row is full. Used by Home's
//  What's blocked card and the website suggestions.
//

import SwiftUI

struct ChipFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// 2.3: tap-to-block website suggestions for a focus. Sites already on the list are left out,
/// so a chip disappears once tapped (it then shows in the list itself).
struct SiteSuggestionChips: View {
    let sites: [String]
    let alreadyAdded: [String]
    let onAdd: (String) -> Void

    var body: some View {
        let remaining = sites.filter { !alreadyAdded.contains($0) }
        if !remaining.isEmpty {
            ChipFlow(spacing: 8) {
                ForEach(remaining, id: \.self) { site in
                    Button { onAdd(site) } label: {
                        Label(site, systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(PawlColor.cleanBg)
                            .foregroundStyle(PawlColor.cleanText)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Block \(site)")
                }
            }
        }
    }
}
