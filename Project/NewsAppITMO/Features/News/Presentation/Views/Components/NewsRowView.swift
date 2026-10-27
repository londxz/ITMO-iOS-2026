//
//  NewsRowView.swift
//  NewsAppITMO
//
//  Created by n.a.grebenkin on 08.10.2026.
//

import SwiftUI

struct NewsRowView: View {
    let post: PostModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            NewsCoverImageView(url: post.coverImageURL)
                .frame(width: 112, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                Text(post.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(3)

                HStack(spacing: 4) {
                    RelativeTimeText(date: post.publishedAt)
                    Text("·")
                    Text(post.author.name)
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
