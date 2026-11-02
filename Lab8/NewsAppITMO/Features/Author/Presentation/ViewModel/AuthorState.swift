struct AuthorState: Equatable, Sendable {
    var author: AuthorModel?
    var posts: [PostModel] = []

    var initialLoad: LoadState = .idle
    var paginationLoad: LoadState = .idle

    var currentPage = 1
    var canLoadMore = true
}
