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
        let vm = BookmarksViewModel(storage: storage, router: nil)
        defer { vm.send(.onDisappear) }
        let observation = vm.send(.onAppear)!
        XCTAssertEqual(vm.state.loadState, .loading)
        XCTAssertNil(vm.send(.onAppear))
        await waitUntil { vm.state.loadState == .loaded }
        XCTAssertTrue(vm.state.isEmpty)
        try await storage.save(post: post("1"))
        await waitUntil { vm.state.bookmarks.count == 1 }
        vm.send(.searchTextChanged("missing"))
        XCTAssertTrue(vm.state.hasNoSearchResults)
        vm.send(.onDisappear)
        XCTAssertTrue(observation.isCancelled)
        await observation.value

        try await storage.save(post: post("2"))
        XCTAssertEqual(vm.state.bookmarks.count, 1)
        XCTAssertNotNil(vm.send(.onAppear))
        await waitUntil { vm.state.bookmarks.count == 2 }
        XCTAssertEqual(vm.state.searchText, "missing")
        XCTAssertEqual(vm.state.loadState, .loaded)
    }

    func testCorruptFileShowsErrorAndRetryRecovers() async throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("broken json".utf8).write(to: file)
        let vm = BookmarksViewModel(storage: FileBookmarksStorage(fileURL: file), router: nil)
        defer { vm.send(.onDisappear) }
        await vm.send(.onAppear)?.value
        guard case .failed = vm.state.loadState else { return XCTFail("Expected file read error") }
        XCTAssertTrue(vm.state.isEmpty)
        try JSONEncoder().encode([post("1")]).write(to: file)
        vm.send(.retry)
        await waitUntil { vm.state.loadState == .loaded }
        XCTAssertEqual(vm.state.bookmarks.map(\.id), ["1"])
    }

    func testDeletionWaitsForPersistenceAndFailureKeepsArticle() async throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let storage = ControlledRemovalStorage(fileURL: file)
        try await storage.save(post: post("1"))
        let vm = BookmarksViewModel(storage: storage, router: nil)
        defer { vm.send(.onDisappear) }
        vm.send(.onAppear)
        await waitUntil { vm.state.bookmarks.count == 1 }
        let failedDelete = vm.send(.delete(id: "1"))!
        await waitUntil { await storage.isRemoving }
        XCTAssertEqual(vm.state.bookmarks.count, 1)
        XCTAssertEqual(vm.state.deletingID, "1")
        XCTAssertNil(vm.send(.delete(id: "1")))
        await storage.finishRemoval(error: CocoaError(.fileWriteNoPermission))
        await failedDelete.value
        XCTAssertEqual(vm.state.bookmarks.map(\.id), ["1"])
        XCTAssertNotNil(vm.state.message)
        XCTAssertNil(vm.state.deletingID)
        vm.send(.dismissMessage)
        XCTAssertNil(vm.state.message)

        let successfulDelete = vm.send(.delete(id: "1"))!
        await waitUntil { await storage.isRemoving }
        await storage.finishRemoval()
        await successfulDelete.value
        await waitUntil { vm.state.isEmpty }
        let persisted = try await FileBookmarksStorage(fileURL: file).getBookmarks()
        XCTAssertTrue(persisted.isEmpty)
    }

    func testLeavingCancelsMutationAndReopeningReconcilesDisk() async throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let storage = ControlledRemovalStorage(fileURL: file)
        try await storage.save(post: post("1"))
        let vm = BookmarksViewModel(storage: storage, router: nil)
        defer { vm.send(.onDisappear) }
        vm.send(.onAppear)
        await waitUntil { vm.state.bookmarks.count == 1 }
        let deletion = vm.send(.delete(id: "1"))!
        await waitUntil { await storage.isRemoving }
        vm.send(.onDisappear)
        XCTAssertTrue(deletion.isCancelled)
        XCTAssertNil(vm.state.deletingID)
        // An atomic disk write already in progress may finish after cancellation.
        await storage.finishRemoval()
        await deletion.value
        XCTAssertNil(vm.state.message)
        vm.send(.onAppear)
        await waitUntil { vm.state.isEmpty && vm.state.loadState == .loaded }
    }

    func testSelectionRoutesThroughInjectedRouter() {
        let router = BookmarksTestRouter()
        let vm = BookmarksViewModel(storage: FileBookmarksStorage(fileURL: temporaryFile()), router: router)
        vm.send(.didSelectPost(id: "saved-post"))
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
