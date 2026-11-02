//
//  NewsHeroCardView.swift
//  NewsAppITMO
//
//  Created by n.a.grebenkin on 08.10.2026.
//

import SwiftUI

struct NewsHeroCardView: View {
    let post: PostModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NewsCoverImageView(url: post.coverImageURL)
                .aspectRatio(1000 / 420, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(post.title)
                .font(.headline)
                .lineLimit(3)

            if !post.summary.isEmpty {
                Text(post.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                RelativeTimeText(date: post.publishedAt)
                Label("\(post.reactionsCount)", systemImage: "heart.fill")
                Label("\(post.commentsCount)", systemImage: "bubble.right")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
        }
        .multilineTextAlignment(.leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
