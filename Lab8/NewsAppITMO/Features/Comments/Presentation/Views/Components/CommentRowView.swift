import SwiftUI

struct CommentRowView: View {
    let item: CommentThreadItem
    let imageCache: any ImageCache

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CachedAsyncImage(url: item.comment.authorAvatarURL, imageCache: imageCache) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.secondary.opacity(0.12))
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.comment.authorName)
                        .font(.subheadline.weight(.semibold))
                    RelativeTimeText(date: item.comment.createdAt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(item.comment.text)
                    .font(.body)
                    .textSelection(.enabled)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, CGFloat(min(item.depth, 4)) * 20)
        .padding(.vertical, 12)
    }
}
