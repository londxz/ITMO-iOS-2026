import XCTest
@testable import NewsAppITMO

@MainActor
final class BookmarksViewModelTests: XCTestCase {
    func testSearchIsLocalCaseInsensitiveAndPreservesSource() {
        var state = BookmarksState(bookmarks: [post("1", title: "Swift Concurrency"), post("2", title: "Новости")])
        state.searchText = " sWiFt "
        XCTAssertEqual(state.filteredBookmarks.map(\.id), ["1"])
        state.searchText = "нОвОсТи"
        XCTAssertEqual(state.filteredBookmarks.map(\.id), ["2"])
        state.searchText = "AUTHOR"
        XCTAssertEqual(state.filteredBookmarks.count, 2)
        state.searchText = "ios"
        XCTAssertEqual(state.filteredBookmarks.count, 2)
        state.searchText = "absent"
        XCTAssertFalse(state.isEmpty)
        XCTAssertTrue(state.hasNoSearchResults)
        XCTAssertEqual(state.bookmarks.count, 2)
        state.searchText = "  "
        XCTAssertEqual(state.filteredBookmarks, state.bookmarks)
        XCTAssertTrue(BookmarksState().isEmpty)
        XCTAssertFalse(BookmarksState().hasNoSearchResults)
    }

    func testSingleSubscriptionReceivesSavesAndCanRestartAfterDisappearing() async throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let storage = FileBookmarksStorage(fileURL: file)
        let viewModel = BookmarksViewModel(storage: storage, router: nil)
        defer { viewModel.send(.onDisappear) }
        let observation = viewModel.send(.onAppear)!
        XCTAssertEqual(viewModel.state.loadState, .loading)
        XCTAssertNil(viewModel.send(.onAppear))
        await waitUntil { viewModel.state.loadState == .loaded }
        XCTAssertTrue(viewModel.state.isEmpty)
        try await storage.save(post: post("1"))
        await waitUntil { viewModel.state.bookmarks.count == 1 }
        viewModel.send(.searchTextChanged("missing"))
        XCTAssertTrue(viewModel.state.hasNoSearchResults)
        viewModel.send(.onDisappear)
        XCTAssertTrue(observation.isCancelled)
        await observation.value

        try await storage.save(post: post("2"))
        XCTAssertEqual(viewModel.state.bookmarks.count, 1)
        XCTAssertNotNil(viewModel.send(.onAppear))
        await waitUntil { viewModel.state.bookmarks.count == 2 }
        XCTAssertEqual(viewModel.state.searchText, "missing")
        XCTAssertEqual(viewModel.state.loadState, .loaded)
    }

    func testCorruptFileShowsErrorAndRetryRecovers() async throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("broken json".utf8).write(to: file)
        let viewModel = BookmarksViewModel(storage: FileBookmarksStorage(fileURL: file), router: nil)
        defer { viewModel.send(.onDisappear) }
        await viewModel.send(.onAppear)?.value
        guard case .failed = viewModel.state.loadState else { return XCTFail("Expected file read error") }
        XCTAssertTrue(viewModel.state.isEmpty)
        try JSONEncoder().encode([post("1")]).write(to: file)
        viewModel.send(.retry)
        await waitUntil { viewModel.state.loadState == .loaded }
        XCTAssertEqual(viewModel.state.bookmarks.map(\.id), ["1"])
    }

    func testDeletionWaitsForPersistenceAndFailureKeepsArticle() async throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let storage = ControlledRemovalStorage(fileURL: file)
        try await storage.save(post: post("1"))
        let viewModel = BookmarksViewModel(storage: storage, router: nil)
        defer { viewModel.send(.onDisappear) }
        viewModel.send(.onAppear)
        await waitUntil { viewModel.state.bookmarks.count == 1 }
        let failedDelete = viewModel.send(.delete(id: "1"))!
        await waitUntil { await storage.isRemoving }
        XCTAssertEqual(viewModel.state.bookmarks.count, 1)
        XCTAssertEqual(viewModel.state.deletingID, "1")
        XCTAssertNil(viewModel.send(.delete(id: "1")))
        await storage.finishRemoval(error: CocoaError(.fileWriteNoPermission))
        await failedDelete.value
        XCTAssertEqual(viewModel.state.bookmarks.map(\.id), ["1"])
        XCTAssertNotNil(viewModel.state.message)
        XCTAssertNil(viewModel.state.deletingID)
        viewModel.send(.dismissMessage)
        XCTAssertNil(viewModel.state.message)

        let successfulDelete = viewModel.send(.delete(id: "1"))!
        await waitUntil { await storage.isRemoving }
        await storage.finishRemoval()
        await successfulDelete.value
        await waitUntil { viewModel.state.isEmpty }
        let persisted = try await FileBookmarksStorage(fileURL: file).getBookmarks()
        XCTAssertTrue(persisted.isEmpty)
    }

    func testLeavingCancelsMutationAndReopeningReconcilesDisk() async throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let storage = ControlledRemovalStorage(fileURL: file)
        try await storage.save(post: post("1"))
        let viewModel = BookmarksViewModel(storage: storage, router: nil)
        defer { viewModel.send(.onDisappear) }
        viewModel.send(.onAppear)
        await waitUntil { viewModel.state.bookmarks.count == 1 }
        let deletion = viewModel.send(.delete(id: "1"))!
        await waitUntil { await storage.isRemoving }
        viewModel.send(.onDisappear)
        XCTAssertTrue(deletion.isCancelled)
        XCTAssertNil(viewModel.state.deletingID)
        // An atomic disk write already in progress may finish after cancellation.
        await storage.finishRemoval()
        await deletion.value
        XCTAssertNil(viewModel.state.message)
        viewModel.send(.onAppear)
        await waitUntil { viewModel.state.isEmpty && viewModel.state.loadState == .loaded }
    }

    func testSelectionRoutesThroughInjectedRouter() {
        let router = BookmarksTestRouter()
        let viewModel = BookmarksViewModel(storage: FileBookmarksStorage(fileURL: temporaryFile()), router: router)
        viewModel.send(.didSelectPost(id: "saved-post"))
        XCTAssertEqual(router.selectedID, "saved-post")
    }

    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    private func post(_ id: String, title: String = "Article") -> PostModel {
        PostModel(id: id, title: title, summary: "Summary", bodyMarkdown: "# Saved body",
                  publishedAt: .distantPast, coverImageURL: nil, readingTimeMinutes: 3,
                  reactionsCount: 2, commentsCount: 1, tags: ["ios"],
                  author: AuthorModel(id: "author", username: "username", name: "Author", avatarURL: nil,
                                      bio: nil, location: nil, websiteURL: nil, joinedAt: nil), webURL: nil)
    }

    private func waitUntil(_ condition: () async -> Bool) async {
        for _ in 0..<1000 {
            if await condition() { return }
            await Task.yield()
        }
        XCTFail("Expected state was not published")
    }
}

private actor ControlledRemovalStorage: BookmarksStorage {
    private let backend: FileBookmarksStorage
    private var removal: CheckedContinuation<Void, any Error>?
    var isRemoving: Bool { removal != nil }

    init(fileURL: URL) { backend = FileBookmarksStorage(fileURL: fileURL) }
    func getBookmarks() async throws -> [PostModel] { try await backend.getBookmarks() }
    func isBookmarked(id: String) async -> Bool { await backend.isBookmarked(id: id) }
    func save(post: PostModel) async throws { try await backend.save(post: post) }
    func remove(id: String) async throws {
        try await withCheckedThrowingContinuation { removal = $0 }
        try await backend.remove(id: id)
    }
    func finishRemoval(error: (any Error)? = nil) {
        if let error { removal?.resume(throwing: error) } else { removal?.resume() }
        removal = nil
    }
    nonisolated func observeBookmarks() -> AsyncStream<[PostModel]> { backend.observeBookmarks() }
}

@MainActor
private final class BookmarksTestRouter: BookmarksRouting {
    var selectedID: String?
    func openPost(id: String) { selectedID = id }
}
