import XCTest
@testable import NewsAppITMO

@MainActor
final class PostDetailViewModelTests: XCTestCase {
    func testSavedArticleOpensOfflineWithFullMarkdown() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let storage = FileBookmarksStorage(fileURL: file)
        let post = makePost()
        try await storage.save(post: post)
        let repository = DetailTestRepository(result: .failure(.transport(.notConnectedToInternet)))
        let viewModel = makeViewModel(repository, storage)

        await viewModel.send(.onAppear)?.value

        XCTAssertEqual(viewModel.state.post, post)
        XCTAssertEqual(viewModel.state.post?.bodyMarkdown, "# Heading\n\n```swift\nlet value = 1\n```")
        XCTAssertEqual(viewModel.state.loadState, .loaded)
        XCTAssertTrue(viewModel.state.isBookmarked)
        XCTAssertNil(viewModel.state.refreshError)
    }

    func testRefreshOfSavedArticleReportsFailureButKeepsArticle() async {
        let storage = DetailTestBookmarks(posts: [makePost()])
        let repository = DetailTestRepository(result: .success(makePost(title: "Online")))
        let viewModel = makeViewModel(repository, storage)
        await viewModel.send(.onAppear)?.value
        await repository.setResult(.failure(.transport(.notConnectedToInternet)))
        await viewModel.send(.refresh)?.value
        XCTAssertEqual(viewModel.state.post?.title, "Online")
        XCTAssertEqual(viewModel.state.loadState, .loaded)
        XCTAssertEqual(viewModel.state.refreshError, .networkUnavailable)
        viewModel.send(.dismissRefreshError)
        XCTAssertNil(viewModel.state.refreshError)
    }

    func testIncompleteSavedArticleDoesNotHideNetworkError() async {
        let storage = DetailTestBookmarks(posts: [makePost(body: nil)])
        let repository = DetailTestRepository(
            result: .failure(.transport(.notConnectedToInternet))
        )
        let viewModel = makeViewModel(repository, storage)
        await viewModel.send(.onAppear)?.value
        XCTAssertEqual(viewModel.state.loadState, .failed(.networkUnavailable))
        XCTAssertNil(viewModel.state.post)
    }

    func testLocalReadErrorDoesNotHideNetworkSuccess() async {
        let storage = DetailTestBookmarks()
        await storage.failReads()
        let viewModel = makeViewModel(DetailTestRepository(result: .success(makePost())), storage)
        await viewModel.send(.onAppear)?.value
        XCTAssertEqual(viewModel.state.post, makePost())
        XCTAssertEqual(viewModel.state.loadState, .loaded)
    }

    func testRefreshPreservesContentAndIgnoresSupersededResponse() async {
        let repository = DetailTestRepository(result: .success(makePost()))
        let viewModel = makeViewModel(repository, DetailTestBookmarks())
        await viewModel.send(.onAppear)?.value
        await repository.holdRequests()
        let old = viewModel.send(.refresh)!
        await waitUntil { await repository.count == 2 }
        XCTAssertEqual(viewModel.state.post, makePost())
        let new = viewModel.send(.retry)!
        await waitUntil { await repository.count == 3 }
        await repository.finish(3, .success(makePost(title: "New")))
        await new.value
        await repository.finish(2, .success(makePost(title: "Stale")))
        await old.value
        XCTAssertEqual(viewModel.state.post?.title, "New")
        XCTAssertEqual(viewModel.state.loadState, .loaded)
    }

    func testFailedRefreshKeepsContentAndRetryRecovers() async {
        let repository = DetailTestRepository(result: .success(makePost()))
        let viewModel = makeViewModel(repository, DetailTestBookmarks())
        await viewModel.send(.onAppear)?.value
        await repository.setResult(.failure(.serverError(statusCode: 503)))
        await viewModel.send(.refresh)?.value
        XCTAssertEqual(viewModel.state.post, makePost())
        XCTAssertEqual(viewModel.state.loadState, .loaded)
        XCTAssertEqual(viewModel.state.refreshError, .serverUnavailable)
        await repository.setResult(.success(makePost(title: "Recovered")))
        await viewModel.send(.retry)?.value
        XCTAssertEqual(viewModel.state.post?.title, "Recovered")
        XCTAssertEqual(viewModel.state.loadState, .loaded)
        XCTAssertNil(viewModel.state.refreshError)
    }

    func testBookmarkWritesAreNotOptimisticAndFinishAfterLeaving() async {
        let storage = DetailTestBookmarks()
        let viewModel = makeViewModel(DetailTestRepository(result: .success(makePost())), storage)
        await viewModel.send(.onAppear)?.value
        await storage.holdWrites()
        let saving = viewModel.send(.toggleBookmark)!
        await waitUntil { await storage.writeStarted }
        XCTAssertFalse(viewModel.state.isBookmarked)
        XCTAssertEqual(viewModel.state.bookmarkUpdate, .loading)
        XCTAssertNil(viewModel.send(.toggleBookmark))
        viewModel.send(.onDisappear)
        XCTAssertFalse(saving.isCancelled)
        await storage.finishWrite()
        await saving.value
        XCTAssertTrue(viewModel.state.isBookmarked)
        let saved = try? await storage.getBookmarks()
        XCTAssertEqual(saved, [makePost()])

        await storage.failWrites()
        await viewModel.send(.toggleBookmark)?.value
        XCTAssertTrue(viewModel.state.isBookmarked)
        XCTAssertNotNil(viewModel.state.message)
        viewModel.send(.dismissMessage)
        XCTAssertNil(viewModel.state.message)

        await storage.allowWrites()
        await viewModel.send(.toggleBookmark)?.value
        XCTAssertFalse(viewModel.state.isBookmarked)
        let remaining = try? await storage.getBookmarks()
        XCTAssertEqual(remaining, [])
    }

    func testDisappearCancelsLoadAndLateResponseCannotUpdateState() async {
        let repository = DetailTestRepository(result: .success(makePost()))
        await repository.holdRequests()
        let viewModel = makeViewModel(repository, DetailTestBookmarks())
        let task = viewModel.send(.onAppear)!
        await waitUntil { await repository.count == 1 }
        XCTAssertNil(viewModel.send(.onAppear))
        viewModel.send(.onDisappear)
        XCTAssertTrue(task.isCancelled)
        await repository.finish(1, .success(makePost()))
        await task.value
        XCTAssertNil(viewModel.state.post)
        XCTAssertEqual(viewModel.state.loadState, .idle)
    }

    func testRoutesUseLoadedAuthorAndRequestedPostID() async {
        let router = DetailTestRouter()
        let viewModel = PostDetailViewModel(
            postID: "post",
            repository: DetailTestRepository(result: .success(makePost())),
            bookmarksStorage: DetailTestBookmarks(),
            router: router
        )
        await viewModel.send(.onAppear)?.value
        viewModel.send(.didSelectAuthor)
        viewModel.send(.didSelectComments)
        XCTAssertEqual(router.authorID, "author")
        XCTAssertEqual(router.username, "username")
        XCTAssertEqual(router.commentsID, "post")
    }

    func testReturningReconcilesBookmarkChangesWithoutRefetchingArticle() async {
        let repository = DetailTestRepository(result: .success(makePost()))
        let storage = DetailTestBookmarks()
        let viewModel = makeViewModel(repository, storage)
        await viewModel.send(.onAppear)?.value
        viewModel.send(.onDisappear)
        try? await storage.save(post: makePost())
        await viewModel.send(.onAppear)?.value
        XCTAssertTrue(viewModel.state.isBookmarked)
        let count = await repository.count
        XCTAssertEqual(count, 1)
    }

    private func makeViewModel(
        _ repository: DetailTestRepository,
        _ storage: any BookmarksStorage
    ) -> PostDetailViewModel {
        PostDetailViewModel(postID: "post", repository: repository, bookmarksStorage: storage, router: nil)
    }

    private func makePost(
        title: String = "Article",
        body: String? = "# Heading\n\n```swift\nlet value = 1\n```"
    ) -> PostModel {
        PostModel(id: "post", title: title, summary: "Summary", bodyMarkdown: body,
                  publishedAt: .distantPast, coverImageURL: nil, readingTimeMinutes: 3,
                  reactionsCount: 2, commentsCount: 1, tags: ["swift"],
                  author: AuthorModel(id: "author", username: "username", name: "Author", avatarURL: nil,
                                      bio: nil, location: nil, websiteURL: nil, joinedAt: nil),
                  webURL: URL(string: "https://dev.to/article"))
    }

    private func waitUntil(_ condition: () async -> Bool) async {
        for _ in 0..<1000 {
            if await condition() { return }
            await Task.yield()
        }
        XCTFail("Operation did not start")
    }
}

private actor DetailTestRepository: PostDetailRepository {
    private var result: Result<PostModel, NetworkError>
    private var held = false
    private var pending: [Int: CheckedContinuation<PostModel, any Error>] = [:]
    private(set) var count = 0

    init(result: Result<PostModel, NetworkError>) { self.result = result }
    func setResult(_ result: Result<PostModel, NetworkError>) { self.result = result }
    func holdRequests() { held = true }
    func fetchPost(id: String) async throws -> PostModel {
        count += 1
        if held {
            let request = count
            return try await withCheckedThrowingContinuation { pending[request] = $0 }
        }
        return try result.get()
    }
    func finish(_ request: Int, _ result: Result<PostModel, NetworkError>) {
        pending.removeValue(forKey: request)?.resume(with: result.mapError { $0 as any Error })
    }
}

private actor DetailTestBookmarks: BookmarksStorage {
    private var posts: [PostModel]
    private var readsFail = false
    private var writesFail = false
    private var writesHeld = false
    private var writeContinuation: CheckedContinuation<Void, Never>?
    private(set) var writeStarted = false

    init(posts: [PostModel] = []) { self.posts = posts }
    func failReads() { readsFail = true }
    func failWrites() { writesFail = true }
    func allowWrites() { writesFail = false; writesHeld = false }
    func holdWrites() { writesHeld = true }
    func finishWrite() { writeContinuation?.resume(); writeContinuation = nil; writesHeld = false }
    func getBookmarks() throws -> [PostModel] {
        if readsFail { throw CocoaError(.fileReadCorruptFile) }
        return posts
    }
    func isBookmarked(id: String) -> Bool { posts.contains { $0.id == id } }
    func save(post: PostModel) async throws {
        writeStarted = true
        if writesHeld { await withCheckedContinuation { writeContinuation = $0 } }
        if writesFail { throw CocoaError(.fileWriteNoPermission) }
        posts.removeAll { $0.id == post.id }
        posts.append(post)
    }
    func remove(id: String) throws {
        if writesFail { throw CocoaError(.fileWriteNoPermission) }
        posts.removeAll { $0.id == id }
    }
    nonisolated func observeBookmarks() -> AsyncStream<[PostModel]> { AsyncStream { $0.finish() } }
}

@MainActor
private final class DetailTestRouter: PostDetailRouting {
    var authorID: String?
    var username: String?
    var commentsID: String?
    func openAuthor(id: String?, username: String) { authorID = id; self.username = username }
    func openComments(postID: String) { commentsID = postID }
}

final class PostDetailContractTests: XCTestCase {
    func testRepositoryMapsSingleArticleWithDetailTagFormat() async throws {
        let data = Data("""
            {"id":42,"title":"Article","published_at":"2026-10-01T12:00:00Z",
             "body_markdown":"# Full body","reading_time_minutes":3,
             "public_reactions_count":2,"comments_count":1,"tag_list":"swift, ios",
             "url":"https://dev.to/article","user":{"name":"Author","username":"author","user_id":7}}
            """.utf8)
        let post = try await PostDetailRepositoryImpl(client: DetailContractClient(data: data)).fetchPost(id: "42")
        XCTAssertEqual(post.id, "42")
        XCTAssertEqual(post.tags, ["swift", "ios"])
        XCTAssertEqual(post.bodyMarkdown, "# Full body")
        XCTAssertEqual(post.author.id, "7")
    }

    func testArticleDTOStillDecodesFeedTagArray() throws {
        let data = Data("""
            {"id":42,"title":"Article","published_at":"2026-10-01T12:00:00Z",
             "reading_time_minutes":3,"public_reactions_count":2,"comments_count":1,
             "tag_list":["news","swift"],"user":{"name":"Author","username":"author"}}
            """.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(ArticleDTO.self, from: data)
        XCTAssertEqual(ArticleMapper.toDomain(dto).tags, ["news", "swift"])
    }
}

private actor DetailContractClient: HTTPClient {
    let data: Data
    init(data: Data) { self.data = data }
    func send<T: Decodable & Sendable>(_ endpoint: any Endpoint) async throws -> T {
        XCTAssertEqual(endpoint.path, "\(APIPath.articles)/42")
        XCTAssertEqual(endpoint.method, .get)
        XCTAssertTrue(endpoint.queryItems.isEmpty)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}
