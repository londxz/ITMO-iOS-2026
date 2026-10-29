struct CommentThreadItem: Identifiable, Equatable, Sendable {
    let comment: CommentModel
    let depth: Int

    var id: String { comment.id }
}

struct CommentsState: Equatable, Sendable {
    var comments: [CommentModel] = []
    var loadState: LoadState = .idle
    var refreshError: AppError?

    var threadItems: [CommentThreadItem] {
        var items: [CommentThreadItem] = []
        flatten(comments: comments, into: &items)
        return items
    }

    var totalCount: Int { threadItems.count }
    var isEmpty: Bool { comments.isEmpty }

    private func flatten(
        comments: [CommentModel],
        depth: Int = 0,
        into items: inout [CommentThreadItem]
    ) {
        for comment in comments {
            items.append(CommentThreadItem(comment: comment, depth: depth))
            flatten(comments: comment.children, depth: depth + 1, into: &items)
        }
    }
}
