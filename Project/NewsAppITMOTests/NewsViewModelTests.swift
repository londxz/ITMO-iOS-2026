import XCTest
@testable import NewsAppITMO

@MainActor
final class NewsViewModelTests: XCTestCase {
    func testFirstLoadPublishesHeroAndFreshPosts() async throws {
        try await withViewModel { sut, repository in
            let hero = makePost("hero")
            let posts = makePage()
            let task = try XCTUnwrap(sut.send(.onAppear))
            XCTAssertEqual(sut.state.initialLoad, .loading)
            XCTAssertNil(sut.send(.loadMore))

            try await completeFirstPage(repository, hero: hero, posts: posts)
            await task.value

            XCTAssertEqual(sut.state.heroPost, hero)
            XCTAssertEqual(sut.state.posts, posts)
            XCTAssertEqual(sut.state.initialLoad, .loaded)
            XCTAssertEqual(sut.state.currentPage, 1)
            XCTAssertTrue(sut.state.canLoadMore)
            XCTAssertFalse(sut.state.isEmpty)
            await assertRequestCount(2, repository: repository)
        }
    }

    func testEmptyResponseProducesLoadedEmptyFeed() async throws {
        try await withViewModel { sut, repository in
            try await load(sut, repository, hero: nil, posts: [])
            XCTAssertEqual(sut.state.initialLoad, .loaded)
            XCTAssertTrue(sut.state.isEmpty)
            XCTAssertFalse(sut.state.canLoadMore)
            XCTAssertNil(sut.send(.loadMore))
        }
    }

    func testMissingHeroKeepsAllFreshPosts() async throws {
        try await withViewModel { sut, repository in
            let posts = makePage(count: 3)
            try await load(sut, repository, hero: nil, posts: posts)
            XCTAssertNil(sut.state.heroPost)
            XCTAssertEqual(sut.state.posts, posts)
            XCTAssertFalse(sut.state.isEmpty)
        }
    }

    func testDayTopFailureProducesError() async throws {
        try await assertFirstLoadFailure(.dayTop)
    }

    func testFreshPostsFailureProducesError() async throws {
        try await assertFirstLoadFailure(.fresh(page: 1, perPage: 20))
    }

    private func assertFirstLoadFailure(_ failingKind: MockNewsRepository.Kind) async throws {
        try await withViewModel { sut, repository in
            let task = try XCTUnwrap(sut.send(.onAppear))
            let heroRequest = try await repository.waitForRequest(.dayTop)
            let freshRequest = try await repository.waitForRequest(.fresh(page: 1, perPage: 20))
            if failingKind == .dayTop {
                try await repository.fail(heroRequest, error: NetworkError.transport(.notConnectedToInternet))
                try await repository.succeed(freshRequest, posts: makePage())
            } else {
                try await repository.succeed(heroRequest, hero: makePost("hero"))
                try await repository.fail(freshRequest, error: NetworkError.transport(.notConnectedToInternet))
            }
            await task.value

            XCTAssertEqual(sut.state.initialLoad, .failed(.networkUnavailable))
            XCTAssertTrue(sut.state.isEmpty)
            XCTAssertNil(sut.send(.loadMore))
        }
    }

    func testRepeatedAppearanceDoesNotStartAnotherLoad() async throws {
        try await withViewModel { sut, repository in
            let task = try XCTUnwrap(sut.send(.onAppear))
            XCTAssertNil(sut.send(.onAppear))
            try await completeFirstPage(repository, posts: makePage())
            await task.value
            XCTAssertNil(sut.send(.onAppear))
            await assertRequestCount(2, repository: repository)
        }
    }

    func testFirstPageExcludesHeroAndUsesOriginalPageSizeForPagination() async throws {
        try await withViewModel { sut, repository in
            let posts = makePage()
            let hero = posts[0]
            try await load(sut, repository, hero: hero, posts: posts)
            XCTAssertEqual(sut.state.posts, Array(posts.dropFirst()))
            XCTAssertEqual(sut.state.heroPost, hero)
            XCTAssertTrue(sut.state.canLoadMore)
        }
    }

    func testPaginationAppendsPostsAndAdvancesPage() async throws {
        try await withViewModel { sut, repository in
            let first = makePage()
            let second = makePage("second")
            try await load(sut, repository, posts: first)
            let task = try XCTUnwrap(sut.send(.loadMore))
            XCTAssertEqual(sut.state.paginationLoad, .loading)
            let request = try await repository.waitForRequest(.fresh(page: 2, perPage: 20))
            try await repository.succeed(request, posts: second)
            await task.value

            XCTAssertEqual(sut.state.posts, first + second)
            XCTAssertEqual(sut.state.currentPage, 2)
            XCTAssertEqual(sut.state.paginationLoad, .loaded)
            XCTAssertTrue(sut.state.canLoadMore)

            let thirdTask = try XCTUnwrap(sut.send(.loadMore))
            let thirdRequest = try await repository.waitForRequest(.fresh(page: 3, perPage: 20))
            try await repository.succeed(thirdRequest, posts: [])
            await thirdTask.value
            XCTAssertEqual(sut.state.currentPage, 3)
            XCTAssertEqual(sut.state.posts, first + second)
            XCTAssertFalse(sut.state.canLoadMore)
            XCTAssertNil(sut.send(.loadMore))
        }
    }

    func testPaginationRemovesHeroExistingAndWithinPageDuplicates() async throws {
        try await withViewModel { sut, repository in
            let hero = makePost("hero")
            let first = makePage()
            let newPost = makePost("new")
            try await load(sut, repository, hero: hero, posts: first)
            let task = try XCTUnwrap(sut.send(.loadMore))
            let request = try await repository.waitForRequest(.fresh(page: 2, perPage: 20))
            // A full page with only one new ID must still permit another page.
            let page = [hero, first[0]] + Array(repeating: newPost, count: 18)
            try await repository.succeed(request, posts: page)
            await task.value

            XCTAssertEqual(sut.state.posts, first + [newPost])
            XCTAssertEqual(sut.state.heroPost, hero)
            XCTAssertTrue(sut.state.canLoadMore)
        }
    }

    func testEmptyPageStopsPagination() async throws {
        try await assertShortPageStopsPagination(count: 0)
    }

    func testSinglePostPageStopsPagination() async throws {
        try await assertShortPageStopsPagination(count: 1)
    }

    func testPageBelowLimitStopsPagination() async throws {
        try await assertShortPageStopsPagination(count: 19)
    }

    private func assertShortPageStopsPagination(count: Int) async throws {
        try await withViewModel { sut, repository in
            let first = makePage()
            let second = makePage("second", count: count)
            try await load(sut, repository, posts: first)
            let task = try XCTUnwrap(sut.send(.loadMore))
            let request = try await repository.waitForRequest(.fresh(page: 2, perPage: 20))
            try await repository.succeed(request, posts: second)
            await task.value
            XCTAssertEqual(sut.state.posts, first + second)
            XCTAssertFalse(sut.state.canLoadMore)
            XCTAssertNil(sut.send(.loadMore))
            await assertRequestCount(3, repository: repository)
        }
    }

    func testRepeatedLoadMoreWhileLoadingIsIgnored() async throws {
        try await withViewModel { sut, repository in
            try await load(sut, repository, posts: makePage())
            let task = try XCTUnwrap(sut.send(.loadMore))
            let request = try await repository.waitForRequest(.fresh(page: 2, perPage: 20))
            XCTAssertNil(sut.send(.loadMore))
            try await repository.succeed(request, posts: [])
            await task.value
            await assertRequestCount(3, repository: repository)
        }
    }

    func testPaginationFailurePreservesFeedAndRetryUsesSamePage() async throws {
        try await withViewModel { sut, repository in
            let first = makePage()
            try await load(sut, repository, posts: first)
            let task = try XCTUnwrap(sut.send(.loadMore))
            let request = try await repository.waitForRequest(.fresh(page: 2, perPage: 20))
            try await repository.fail(request, error: NetworkError.serverUnavailable(statusCode: 503))
            await task.value
            XCTAssertEqual(sut.state.posts, first)
            XCTAssertEqual(sut.state.currentPage, 1)
            XCTAssertEqual(sut.state.initialLoad, .loaded)
            XCTAssertEqual(sut.state.paginationLoad, .failed(.serverUnavailable))
            XCTAssertTrue(sut.state.canLoadMore)

            let retry = try XCTUnwrap(sut.send(.loadMore))
            let retryRequest = try await repository.waitForRequest(.fresh(page: 2, perPage: 20), occurrence: 2)
            let second = makePage("second", count: 2)
            try await repository.succeed(retryRequest, posts: second)
            await retry.value
            XCTAssertEqual(sut.state.posts, first + second)
            XCTAssertEqual(sut.state.currentPage, 2)
            XCTAssertEqual(sut.state.paginationLoad, .loaded)
        }
    }

    func testRefreshReplacesFeedAndResetsPagination() async throws {
        try await withViewModel { sut, repository in
            try await load(sut, repository, hero: makePost("old-hero"), posts: makePage())
            let pagination = try XCTUnwrap(sut.send(.loadMore))
            let request = try await repository.waitForRequest(.fresh(page: 2, perPage: 20))
            try await repository.succeed(request, posts: [])
            await pagination.value
            XCTAssertEqual(sut.state.currentPage, 2)
            XCTAssertFalse(sut.state.canLoadMore)

            let oldPosts = sut.state.posts
            let refresh = try XCTUnwrap(sut.send(.refresh))
            XCTAssertEqual(sut.state.posts, oldPosts)
            XCTAssertEqual(sut.state.initialLoad, .loaded)
            XCTAssertEqual(sut.state.paginationLoad, .idle)
            XCTAssertNil(sut.send(.loadMore))
            let hero = makePost("new-hero")
            let fresh = makePage("refreshed")
            try await completeFirstPage(repository, occurrence: 2, hero: hero, posts: fresh)
            await refresh.value
            XCTAssertEqual(sut.state.heroPost, hero)
            XCTAssertEqual(sut.state.posts, fresh)
            XCTAssertEqual(sut.state.currentPage, 1)
            XCTAssertTrue(sut.state.canLoadMore)
        }
    }

    func testRefreshFailureKeepsExistingFeed() async throws {
        try await withViewModel { sut, repository in
            try await load(sut, repository, hero: makePost("hero"), posts: makePage())
            let previous = sut.state
            let task = try XCTUnwrap(sut.send(.refresh))
            let hero = try await repository.waitForRequest(.dayTop, occurrence: 2)
            let fresh = try await repository.waitForRequest(.fresh(page: 1, perPage: 20), occurrence: 2)
            try await repository.fail(hero, error: NetworkError.decoding)
            try await repository.succeed(fresh, posts: makePage("unused"))
            await task.value
            XCTAssertEqual(sut.state, previous)

            // A failed refresh must also release the guard blocking pagination.
            let pagination = try XCTUnwrap(sut.send(.loadMore))
            let next = try await repository.waitForRequest(.fresh(page: 2, perPage: 20))
            try await repository.succeed(next, posts: [])
            await pagination.value
        }
    }

    func testRefreshRecoversFromInitialFailure() async throws {
        try await withViewModel { sut, repository in
            let initial = try XCTUnwrap(sut.send(.onAppear))
            let hero = try await repository.waitForRequest(.dayTop)
            let fresh = try await repository.waitForRequest(.fresh(page: 1, perPage: 20))
            try await repository.fail(hero, error: NetworkError.decoding)
            try await repository.succeed(fresh, posts: [])
            await initial.value
            XCTAssertEqual(sut.state.initialLoad, .failed(.invalidData))

            let retry = try XCTUnwrap(sut.send(.refresh))
            XCTAssertEqual(sut.state.initialLoad, .loading)
            let posts = makePage(count: 2)
            try await completeFirstPage(repository, occurrence: 2, posts: posts)
            await retry.value
            XCTAssertEqual(sut.state.initialLoad, .loaded)
            XCTAssertEqual(sut.state.posts, posts)
        }
    }

    func testRefreshCancelsPaginationAndIgnoresItsLateResponse() async throws {
        try await withViewModel { sut, repository in
            try await load(sut, repository, posts: makePage())
            let pagination = try XCTUnwrap(sut.send(.loadMore))
            let oldRequest = try await repository.waitForRequest(.fresh(page: 2, perPage: 20))
            let refresh = try XCTUnwrap(sut.send(.refresh))
            try await repository.waitForCancellation(of: oldRequest)
            XCTAssertEqual(sut.state.paginationLoad, .idle)
            let posts = makePage("refreshed")
            try await completeFirstPage(repository, occurrence: 2, posts: posts)
            await refresh.value
            let refreshedState = sut.state

            try await repository.succeed(oldRequest, posts: makePage("stale"))
            await pagination.value
            XCTAssertEqual(sut.state, refreshedState)
        }
    }

    func testNewRefreshCancelsPreviousFirstPageAndIgnoresLateResponse() async throws {
        try await withViewModel { sut, repository in
            let initial = try XCTUnwrap(sut.send(.onAppear))
            let oldHero = try await repository.waitForRequest(.dayTop)
            let oldFresh = try await repository.waitForRequest(.fresh(page: 1, perPage: 20))
            let refresh = try XCTUnwrap(sut.send(.refresh))
            try await repository.waitForCancellation(of: oldHero)
            try await repository.waitForCancellation(of: oldFresh)
            try await completeFirstPage(repository, occurrence: 2, hero: makePost("new-hero"), posts: makePage("new"))
            await refresh.value
            let refreshedState = sut.state

            try await repository.succeed(oldHero, hero: makePost("stale-hero"))
            try await repository.succeed(oldFresh, posts: makePage("stale"))
            await initial.value
            XCTAssertEqual(sut.state, refreshedState)
        }
    }

    func testDisappearanceCancelsFirstLoadAndAllowsLoadingOnReturn() async throws {
        try await withViewModel { sut, repository in
            let initial = try XCTUnwrap(sut.send(.onAppear))
            let hero = try await repository.waitForRequest(.dayTop)
            let fresh = try await repository.waitForRequest(.fresh(page: 1, perPage: 20))
            sut.send(.onDisappear)
            XCTAssertEqual(sut.state.initialLoad, .idle)
            try await repository.waitForCancellation(of: hero)
            try await repository.waitForCancellation(of: fresh)
            try await repository.succeed(hero, hero: makePost("stale"))
            try await repository.succeed(fresh, posts: makePage("stale"))
            await initial.value
            XCTAssertEqual(sut.state.initialLoad, .idle)
            XCTAssertTrue(sut.state.isEmpty)

            let returning = try XCTUnwrap(sut.send(.onAppear))
            let posts = makePage("returned")
            try await completeFirstPage(repository, occurrence: 2, posts: posts)
            await returning.value
            XCTAssertEqual(sut.state.initialLoad, .loaded)
            XCTAssertEqual(sut.state.posts, posts)
        }
    }

    func testDisappearanceCancelsPaginationAndIgnoresLateSuccess() async throws {
        try await assertDisappearanceCancelsPagination(lateSuccess: true)
    }

    func testDisappearanceCancelsPaginationAndIgnoresLateFailure() async throws {
        try await assertDisappearanceCancelsPagination(lateSuccess: false)
    }

    private func assertDisappearanceCancelsPagination(lateSuccess: Bool) async throws {
        try await withViewModel { sut, repository in
            try await load(sut, repository, posts: makePage())
            let previous = sut.state
            let pagination = try XCTUnwrap(sut.send(.loadMore))
            let request = try await repository.waitForRequest(.fresh(page: 2, perPage: 20))
            sut.send(.onDisappear)
            XCTAssertEqual(sut.state, previous)
            try await repository.waitForCancellation(of: request)
            if lateSuccess {
                try await repository.succeed(request, posts: makePage("stale"))
            } else {
                try await repository.fail(request, error: NetworkError.cancelled)
            }
            await pagination.value
            XCTAssertEqual(sut.state, previous)

            let retry = try XCTUnwrap(sut.send(.loadMore))
            let retryRequest = try await repository.waitForRequest(.fresh(page: 2, perPage: 20), occurrence: 2)
            try await repository.succeed(retryRequest, posts: [])
            await retry.value
            XCTAssertEqual(sut.state.currentPage, 2)
        }
    }

    private func assertRequestCount(
        _ count: Int,
        repository: MockNewsRepository,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let requests = await repository.requests
        XCTAssertEqual(requests.count, count, file: file, line: line)
    }

    private func withViewModel(
        _ body: @MainActor (NewsViewModel, MockNewsRepository) async throws -> Void
    ) async throws {
        let repository = MockNewsRepository()
        let sut = NewsViewModel(repository: repository, router: nil)
        do {
            try await body(sut, repository)
        } catch {
            sut.send(.onDisappear)
            await repository.close()
            throw error
        }
        sut.send(.onDisappear)
        await repository.close()
    }

    private func load(
        _ sut: NewsViewModel,
        _ repository: MockNewsRepository,
        hero: PostModel? = nil,
        posts: [PostModel]
    ) async throws {
        let task = try XCTUnwrap(sut.send(.onAppear))
        try await completeFirstPage(repository, hero: hero, posts: posts)
        await task.value
    }

    private func completeFirstPage(
        _ repository: MockNewsRepository,
        occurrence: Int = 1,
        hero: PostModel? = nil,
        posts: [PostModel]
    ) async throws {
        let heroRequest = try await repository.waitForRequest(.dayTop, occurrence: occurrence)
        let freshRequest = try await repository.waitForRequest(.fresh(page: 1, perPage: 20), occurrence: occurrence)
        try await repository.succeed(heroRequest, hero: hero)
        try await repository.succeed(freshRequest, posts: posts)
    }
}
