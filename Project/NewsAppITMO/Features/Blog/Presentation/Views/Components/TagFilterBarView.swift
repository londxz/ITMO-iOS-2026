//
//  TagFilterBarView.swift
//  NewsAppITMO
//
//  Created by n.a.grebenkin on 28.10.2026.
//

import SwiftUI

struct TagFilterBarView: View {
    let tags: [BlogTagModel]
    let selectedTag: BlogTagModel?
    let onSelect: (BlogTagModel?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                TagPillView(
                    title: "Все",
                    isSelected: selectedTag == nil,
                    showsHash: false,
                    action: { onSelect(nil) }
                )

                ForEach(tags) { tag in
                    TagPillView(
                        title: tag.name,
                        isSelected: tag == selectedTag,
                        action: { onSelect(tag) }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }
}
