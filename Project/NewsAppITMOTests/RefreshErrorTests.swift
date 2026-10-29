import XCTest
@testable import NewsAppITMO

@MainActor
final class RefreshErrorTests: XCTestCase {
    func testBlogRefreshFailureKeepsPostsAndReportsError() async {
        let repository = StubBlogRepository(articles: .success(makePage(count: 15)))
        let viewModel = BlogViewModel(repository: repository, router: nil)
        await viewModel.send(.onAppear)?.value
        let loadedPosts = viewModel.state.posts

        await repository.setArticles(.failure(.transport(.notConnectedToInternet)))
        await viewModel.refresh()

        XCTAssertEqual(viewModel.state.posts, loadedPosts)
        XCTAssertEqual(viewModel.state.initialLoad, .loaded)
        XCTAssertEqual(viewModel.state.refreshError, .networkUnavailable)

        await repository.setArticles(.success(makePage("fresh", count: 3)))
        await viewModel.refresh()
        XCTAssertNil(viewModel.state.refreshError)
        XCTAssertEqual(viewModel.state.posts.count, 3)
    }

    func testBlogInitialFailureShowsScreenErrorInsteadOfRefreshError() async {
        let repository = StubBlogRepository(articles: .failure(.transport(.notConnectedToInternet)))
        let viewModel = BlogViewModel(repository: repository, router: nil)
        await viewModel.send(.onAppear)?.value
        XCTAssertEqual(viewModel.state.initialLoad, .failed(.networkUnavailable))
        XCTAssertNil(viewModel.state.refreshError)
    }

    func testBlogCancelledRefreshDoesNotReportError() async {
        let repository = StubBlogRepository(articles: .success(makePage(count: 15)))
        let viewModel = BlogViewModel(repository: repository, router: nil)
        await viewModel.send(.onAppear)?.value

        await repository.setArticles(.failure(.cancelled))
        await viewModel.refresh()
        XCTAssertNil(viewModel.state.refreshError)
        XCTAssertEqual(viewModel.state.initialLoad, .loaded)
    }

    func testAuthorRefreshFailureKeepsProfileAndReportsError() async {
        let repository = StubAuthorRepository()
        let viewModel = AuthorProfileViewModel(authorID: "7", username: "author", repository: repository, router: nil)
        await viewModel.send(.onAppear)?.value
        XCTAssertNotNil(viewModel.state.author)

        await repository.setFailure(.transport(.timedOut))
        await viewModel.refresh()
        XCTAssertNotNil(viewModel.state.author)
        XCTAssertEqual(viewModel.state.refreshError, .networkUnavailable)

        viewModel.send(.dismissRefreshError)
        XCTAssertNil(viewModel.state.refreshError)
    }

    func testCommentsRefreshFailureKeepsCommentsAndReportsError() async {
        let repository = StubCommentsRepository(result: .success([makeComment("1")]))
        let viewModel = CommentsViewModel(postID: "post", repository: repository)
        await viewModel.send(.onAppear)?.value
        XCTAssertEqual(viewModel.state.comments.count, 1)

        await repository.setResult(.failure(.transport(.notConnectedToInternet)))
        await viewModel.refresh()
        XCTAssertEqual(viewModel.state.comments.count, 1)
        XCTAssertEqual(viewModel.state.loadState, .loaded)
        XCTAssertEqual(viewModel.state.refreshError, .networkUnavailable)

        await repository.setResult(.success([makeComment("1"), makeComment("2")]))
        await viewModel.refresh()
        XCTAssertEqual(viewModel.state.comments.count, 2)
        XCTAssertNil(viewModel.state.refreshError)
    }

    func testCommentsInitialFailureShowsScreenError() async {
        let repository = StubCommentsRepository(result: .failure(.transport(.notConnectedToInternet)))
        let viewModel = CommentsViewModel(postID: "post", repository: repository)
        await viewModel.send(.onAppear)?.value
        XCTAssertEqual(viewModel.state.loadState, .failed(.networkUnavailable))
        XCTAssertNil(viewModel.state.refreshError)
    }

    private func makeComment(_ id: String) -> CommentModel {
        CommentModel(
            id: id,
            authorName: "Author",
            authorAvatarURL: nil,
            text: "Comment \(id)",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            children: []
        )
    }
}

private actor StubBlogRepository: BlogRepository {
    private var articles: Result<[PostModel], NetworkError>

    init(articles: Result<[PostModel], NetworkError>) {
        self.articles = articles
    }

    func setArticles(_ articles: Result<[PostModel], NetworkError>) {
        self.articles = articles
    }

    func fetchTags() async throws -> [BlogTagModel] {
        []
    }

    func fetchArticles(tag: String?, sort: BlogSort, page: Int, perPage: Int) async throws -> [PostModel] {
        try articles.get()
    }
}

private actor StubAuthorRepository: AuthorRepository {
    private var failure: NetworkError?

    func setFailure(_ failure: NetworkError?) {
        self.failure = failure
    }

    func fetchAuthor(id: String?, username: String) async throws -> AuthorModel {
        if let failure { throw failure }
        return AuthorModel(
            id: id, username: username, name: "Author",
            avatarURL: nil, bio: nil, location: nil, websiteURL: nil, joinedAt: nil
        )
    }

    func fetchPosts(username: String, page: Int, perPage: Int) async throws -> [PostModel] {
        if let failure { throw failure }
        return makePage("author", count: 2)
    }
}

private actor StubCommentsRepository: CommentsRepository {
    private var result: Result<[CommentModel], NetworkError>

    init(result: Result<[CommentModel], NetworkError>) {
        self.result = result
    }

    func setResult(_ result: Result<[CommentModel], NetworkError>) {
        self.result = result
    }

    func fetchComments(postID: String) async throws -> [CommentModel] {
        try result.get()
    }
}
