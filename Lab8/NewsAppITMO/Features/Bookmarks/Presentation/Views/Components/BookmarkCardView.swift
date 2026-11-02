import SwiftUI

struct BookmarkCardView: View {
    let post: PostModel
    let imageCache: any ImageCache

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AuthorHeaderView(
                author: post.author,
                publishedAt: post.publishedAt,
                imageCache: imageCache,
                showsChevron: false
            )

            Color.secondary.opacity(0.1)
                .overlay {
                    CachedAsyncImage(url: post.coverImageURL, imageCache: imageCache) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            Image(systemName: "doc.richtext")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)

            HStack {
                if let tag = post.tags.first {
                    Text("#\(tag)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.quaternary, in: Capsule())
                }
                Spacer(minLength: 8)
                Text("\(post.readingTimeMinutes) мин чтения")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(post.title)
                .font(.title3.bold())
                .fixedSize(horizontal: false, vertical: true)

            if !post.summary.isEmpty {
                Text(post.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            MetricsBarView(reactionsCount: post.reactionsCount, commentsCount: post.commentsCount)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
    }
}
