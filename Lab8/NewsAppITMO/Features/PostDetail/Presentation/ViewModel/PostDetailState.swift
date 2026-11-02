struct PostDetailState: Equatable, Sendable {
    var post: PostModel?
    var loadState: LoadState = .idle
    var isBookmarked = false
    var bookmarkUpdate: LoadState = .idle
    var message: String?
}
