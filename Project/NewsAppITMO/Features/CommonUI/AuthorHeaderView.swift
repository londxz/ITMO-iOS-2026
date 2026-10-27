//
//  AuthorHeaderView.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 27.10.2026.
//

import SwiftUI

struct AuthorHeaderView: View {
    let author: AuthorModel
    let publishedAt: Date
    let imageCache: any ImageCache
    var showsChevron: Bool = true
    var action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var content: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 3) {
                Text(author.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 5) {
                    RelativeTimeText(date: publishedAt)

                    if !author.username.isEmpty {
                        Text("·")
                        Text("@\(author.username)")
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }

    private var avatar: some View {
        Circle()
            .fill(.quaternary)
            .overlay {
                CachedAsyncImage(
                    url: author.avatarURL,
                    imageCache: imageCache
                ) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        avatarPlaceholder
                    case .empty:
                        if author.avatarURL == nil {
                            avatarPlaceholder
                        } else {
                            ProgressView()
                                .controlSize(.small)
                        }
                    @unknown default:
                        avatarPlaceholder
                    }
                }
            }
            .frame(width: 42, height: 42)
            .clipShape(Circle())
    }

    private var avatarPlaceholder: some View {
        Image(systemName: "person.fill")
            .font(.body)
            .foregroundStyle(.secondary)
    }
}
