import SwiftUI

struct AuthorPostRowView: View {
    let post: PostModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(post.title)
                .font(.headline)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                RelativeTimeText(date: post.publishedAt)
                Text("·")
                Text("\(post.readingTimeMinutes) мин чтения")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            MetricsBarView(
                reactionsCount: post.reactionsCount,
                commentsCount: post.commentsCount
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
    }
}
