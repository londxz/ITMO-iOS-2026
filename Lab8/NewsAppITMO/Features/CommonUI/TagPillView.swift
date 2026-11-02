//
//  TagPillView.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 27.10.2026.
//

import SwiftUI

struct TagPillView: View {
    let title: String
    var isSelected: Bool = false
    var showsHash: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(displayTitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isSelected ? Color.accentColor : Color.secondary.opacity(0.14),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var displayTitle: String {
        guard showsHash, !title.hasPrefix("#") else { return title }
        return "#\(title)"
    }
}
