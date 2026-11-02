import SwiftUI

struct BlogCardView: View {
    let post: PostModel
    let imageCache: any ImageCache
    let onSelectPost: () -> Void
    let onSelectAuthor: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AuthorHeaderView(
                author: post.author,
                publishedAt: post.publishedAt,
                imageCache: imageCache,
                action: onSelectAuthor
            )

            Button(action: onSelectPost) {
                articleContent
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var articleContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if post.coverImageURL != nil {
                cover
            }

            HStack {
                if let tag = post.tags.first {
                    Text("#\(tag)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.quaternary, in: Capsule())
                }
                Spacer(minLength: 8)
                Label("\(post.readingTimeMinutes) мин чтения", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(post.title)
                .font(.title3.bold())
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if !post.summary.isEmpty {
                Text(post.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }

            MetricsBarView(
                reactionsCount: post.reactionsCount,
                commentsCount: post.commentsCount
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var cover: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                CachedAsyncImage(url: post.coverImageURL, imageCache: imageCache) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Image(systemName: "doc.richtext")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    case .empty:
                        ProgressView()
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            .aspectRatio(1000 / 420, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityHidden(true)
    }
}
