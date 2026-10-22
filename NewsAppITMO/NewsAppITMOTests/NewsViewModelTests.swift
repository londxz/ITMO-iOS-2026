import Testing
@testable import NewsAppITMO

@MainActor
struct NewsViewModelTests {
    @Test
    func firstLoadPublishesHeroAndFreshPosts() async throws {
        try await withViewModel { sut, repository in
            let hero = makePost("hero")
            let posts = makePage()
            let task = try #require(sut.send(.onAppear))
            #expect(sut.state.initialLoad == .loading)
            #expect(sut.send(.loadMore) == nil)

            try await completeFirstPage(repository, hero: hero, posts: posts)
            await task.value

            #expect(sut.state.heroPost == hero)
            #expect(sut.state.posts == posts)
            #expect(sut.state.initialLoad == .loaded)
            #expect(sut.state.currentPage == 1)
            #expect(sut.state.canLoadMore)
            #expect(!sut.state.isEmpty)
            #expect(await repository.requests.count == 2)
        }
    }

    @Test
    func emptyResponseProducesLoadedEmptyFeed() async throws {
        try await withViewModel { sut, repository in
            try await load(sut, repository, hero: nil, posts: [])
            #expect(sut.state.initialLoad == .loaded)
            #expect(sut.state.isEmpty)
            #expect(!sut.state.canLoadMore)
            #expect(sut.send(.loadMore) == nil)
        }
    }

    @Test
    func missingHeroKeepsAllFreshPosts() async throws {
        try await withViewModel { sut, repository in
            let posts = makePage(count: 3)
            try await load(sut, repository, hero: nil, posts: posts)
            #expect(sut.state.heroPost == nil)
            #expect(sut.state.posts == posts)
            #expect(!sut.state.isEmpty)
        }
    }

    @Test(arguments: [ControlledNewsRepository.Kind.dayTop, .fresh(page: 1, perPage: 20)])
    func firstLoadFailureProducesError(failingKind: ControlledNewsRepository.Kind) async throws {
        try await withViewModel { sut, repository in
            let task = try #require(sut.send(.onAppear))
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

            #expect(sut.state.initialLoad == .failed(.networkUnavailable))
            #expect(sut.state.isEmpty)
            #expect(sut.send(.loadMore) == nil)
        }
    }

    @Test
    func repeatedAppearanceDoesNotStartAnotherLoad() async throws {
        try await withViewModel { sut, repository in
            let task = try #require(sut.send(.onAppear))
            #expect(sut.send(.onAppear) == nil)
            try await completeFirstPage(repository, posts: makePage())
            await task.value
            #expect(sut.send(.onAppear) == nil)
            #expect(await repository.requests.count == 2)
        }
    }

    @Test
    func firstPageExcludesHeroAndUsesOriginalPageSizeForPagination() async throws {
        try await withViewModel { sut, repository in
            let posts = makePage()
            let hero = posts[0]
            try await load(sut, repository, hero: hero, posts: posts)
            #expect(sut.state.posts == Array(posts.dropFirst()))
            #expect(sut.state.heroPost == hero)
            #expect(sut.state.canLoadMore)
        }
    }

    @Test
    func paginationAppendsPostsAndAdvancesPage() async throws {
        try await withViewModel { sut, repository in
            let first = makePage()
            let second = makePage("second")
            try await load(sut, repository, posts: first)
            let task = try #require(sut.send(.loadMore))
            #expect(sut.state.paginationLoad == .loading)
            let request = try await repository.waitForRequest(.fresh(page: 2, perPage: 20))
            try await repository.succeed(request, posts: second)
            await task.value

            #expect(sut.state.posts == first + second)
            #expect(sut.state.currentPage == 2)
            #expect(sut.state.paginationLoad == .loaded)
            #expect(sut.state.canLoadMore)

            let thirdTask = try #require(sut.send(.loadMore))
            let thirdRequest = try await repository.waitForRequest(.fresh(page: 3, perPage: 20))
            try await repository.succeed(thirdRequest, posts: [])
            await thirdTask.value
            #expect(sut.state.currentPage == 3)
            #expect(sut.state.posts == first + second)
            #expect(!sut.state.canLoadMore)
            #expect(sut.send(.loadMore) == nil)
        }
    }

    @Test
    func paginationRemovesHeroExistingAndWithinPageDuplicates() async throws {
        try await withViewModel { sut, repository in
            let hero = makePost("hero")
            let first = makePage()
            let newPost = makePost("new")
            try await load(sut, repository, hero: hero, posts: first)
            let task = try #require(sut.send(.loadMore))
            let request = try await repository.waitForRequest(.fresh(page: 2, perPage: 20))
            // A full page with only one new ID must still permit another page.
            let page = [hero, first[0]] + Array(repeating: newPost, count: 18)
            try await repository.succeed(request, posts: page)
            await task.value

            #expect(sut.state.posts == first + [newPost])
            #expect(sut.state.heroPost == hero)
            #expect(sut.state.canLoadMore)
        }
    }

    @Test(arguments: [0, 1, 19])
    func shortPageStopsPagination(count: Int) async throws {
        try await withViewModel { sut, repository in
            let first = makePage()
            let second = makePage("second", count: count)
            try await load(sut, repository, posts: first)
            let task = try #require(sut.send(.loadMore))
            let request = try await repository.waitForRequest(.fresh(page: 2, perPage: 20))
            try await repository.succeed(request, posts: second)
            await task.value
            #expect(sut.state.posts == first + second)
            #expect(!sut.state.canLoadMore)
            #expect(sut.send(.loadMore) == nil)
            #expect(await repository.requests.count == 3)
        }
    }

    @Test
    func repeatedLoadMoreWhileLoadingIsIgnored() async throws {
        try await withViewModel { sut, repository in
            try await load(sut, repository, posts: makePage())
            let task = try #require(sut.send(.loadMore))
            let request = try await repository.waitForRequest(.fresh(page: 2, perPage: 20))
            #expect(sut.send(.loadMore) == nil)
            try await repository.succeed(request, posts: [])
            await task.value
            #expect(await repository.requests.count == 3)
        }
    }

    @Test
    func paginationFailurePreservesFeedAndRetryUsesSamePage() async throws {
        try await withViewModel { sut, repository in
            let first = makePage()
            try await load(sut, repository, posts: first)
            let task = try #require(sut.send(.loadMore))
            let request = try await repository.waitForRequest(.fresh(page: 2, perPage: 20))
            try await repository.fail(request, error: NetworkError.serverUnavailable(statusCode: 503))
            await task.value
            #expect(sut.state.posts == first)
            #expect(sut.state.currentPage == 1)
            #expect(sut.state.initialLoad == .loaded)
            #expect(sut.state.paginationLoad == .failed(.serverUnavailable))
            #expect(sut.state.canLoadMore)

            let retry = try #require(sut.send(.loadMore))
            let retryRequest = try await repository.waitForRequest(.fresh(page: 2, perPage: 20), occurrence: 2)
            let second = makePage("second", count: 2)
            try await repository.succeed(retryRequest, posts: second)
            await retry.value
            #expect(sut.state.posts == first + second)
            #expect(sut.state.currentPage == 2)
            #expect(sut.state.paginationLoad == .loaded)
        }
    }

    @Test
    func refreshReplacesFeedAndResetsPagination() async throws {
        try await withViewModel { sut, repository in
            try await load(sut, repository, hero: makePost("old-hero"), posts: makePage())
            let pagination = try #require(sut.send(.loadMore))
            let request = try await repository.waitForRequest(.fresh(page: 2, perPage: 20))
            try await repository.succeed(request, posts: [])
            await pagination.value
            #expect(sut.state.currentPage == 2)
            #expect(!sut.state.canLoadMore)

            let oldPosts = sut.state.posts
            let refresh = try #require(sut.send(.refresh))
            #expect(sut.state.posts == oldPosts)
            #expect(sut.state.initialLoad == .loaded)
            #expect(sut.state.paginationLoad == .idle)
            #expect(sut.send(.loadMore) == nil)
            let hero = makePost("new-hero")
            let fresh = makePage("refreshed")
            try await completeFirstPage(repository, occurrence: 2, hero: hero, posts: fresh)
            await refresh.value
            #expect(sut.state.heroPost == hero)
            #expect(sut.state.posts == fresh)
            #expect(sut.state.currentPage == 1)
            #expect(sut.state.canLoadMore)
        }
    }

    @Test
    func refreshFailureKeepsExistingFeed() async throws {
        try await withViewModel { sut, repository in
            try await load(sut, repository, hero: makePost("hero"), posts: makePage())
            let previous = sut.state
            let task = try #require(sut.send(.refresh))
            let hero = try await repository.waitForRequest(.dayTop, occurrence: 2)
            let fresh = try await repository.waitForRequest(.fresh(page: 1, perPage: 20), occurrence: 2)
            try await repository.fail(hero, error: NetworkError.decoding)
            try await repository.succeed(fresh, posts: makePage("unused"))
            await task.value
            #expect(sut.state == previous)

            // A failed refresh must also release the guard blocking pagination.
            let pagination = try #require(sut.send(.loadMore))
            let next = try await repository.waitForRequest(.fresh(page: 2, perPage: 20))
            try await repository.succeed(next, posts: [])
            await pagination.value
        }
    }

    @Test
    func refreshRecoversFromInitialFailure() async throws {
        try await withViewModel { sut, repository in
            let initial = try #require(sut.send(.onAppear))
            let hero = try await repository.waitForRequest(.dayTop)
            let fresh = try await repository.waitForRequest(.fresh(page: 1, perPage: 20))
            try await repository.fail(hero, error: NetworkError.decoding)
            try await repository.succeed(fresh, posts: [])
            await initial.value
            #expect(sut.state.initialLoad == .failed(.invalidData))

            let retry = try #require(sut.send(.refresh))
            #expect(sut.state.initialLoad == .loading)
            let posts = makePage(count: 2)
            try await completeFirstPage(repository, occurrence: 2, posts: posts)
            await retry.value
            #expect(sut.state.initialLoad == .loaded)
            #expect(sut.state.posts == posts)
        }
    }

    @Test
    func refreshCancelsPaginationAndIgnoresItsLateResponse() async throws {
        try await withViewModel { sut, repository in
            try await load(sut, repository, posts: makePage())
            let pagination = try #require(sut.send(.loadMore))
            let oldRequest = try await repository.waitForRequest(.fresh(page: 2, perPage: 20))
            let refresh = try #require(sut.send(.refresh))
            try await repository.waitForCancellation(of: oldRequest)
            #expect(sut.state.paginationLoad == .idle)
            let posts = makePage("refreshed")
            try await completeFirstPage(repository, occurrence: 2, posts: posts)
            await refresh.value
            let refreshedState = sut.state

            try await repository.succeed(oldRequest, posts: makePage("stale"))
            await pagination.value
            #expect(sut.state == refreshedState)
        }
    }

    @Test
    func newRefreshCancelsPreviousFirstPageAndIgnoresLateResponse() async throws {
        try await withViewModel { sut, repository in
            let initial = try #require(sut.send(.onAppear))
            let oldHero = try await repository.waitForRequest(.dayTop)
            let oldFresh = try await repository.waitForRequest(.fresh(page: 1, perPage: 20))
            let refresh = try #require(sut.send(.refresh))
            try await repository.waitForCancellation(of: oldHero)
            try await repository.waitForCancellation(of: oldFresh)
            try await completeFirstPage(repository, occurrence: 2, hero: makePost("new-hero"), posts: makePage("new"))
            await refresh.value
            let refreshedState = sut.state

            try await repository.succeed(oldHero, hero: makePost("stale-hero"))
            try await repository.succeed(oldFresh, posts: makePage("stale"))
            await initial.value
            #expect(sut.state == refreshedState)
        }
    }

    @Test
    func disappearanceCancelsFirstLoadAndAllowsLoadingOnReturn() async throws {
        try await withViewModel { sut, repository in
            let initial = try #require(sut.send(.onAppear))
            let hero = try await repository.waitForRequest(.dayTop)
            let fresh = try await repository.waitForRequest(.fresh(page: 1, perPage: 20))
            sut.send(.onDisappear)
            #expect(sut.state.initialLoad == .idle)
            try await repository.waitForCancellation(of: hero)
            try await repository.waitForCancellation(of: fresh)
            try await repository.succeed(hero, hero: makePost("stale"))
            try await repository.succeed(fresh, posts: makePage("stale"))
            await initial.value
            #expect(sut.state.initialLoad == .idle)
            #expect(sut.state.isEmpty)

            let returning = try #require(sut.send(.onAppear))
            let posts = makePage("returned")
            try await completeFirstPage(repository, occurrence: 2, posts: posts)
            await returning.value
            #expect(sut.state.initialLoad == .loaded)
            #expect(sut.state.posts == posts)
        }
    }

    @Test(arguments: [true, false])
    func disappearanceCancelsPaginationWithoutChangingFeed(lateSuccess: Bool) async throws {
        try await withViewModel { sut, repository in
            try await load(sut, repository, posts: makePage())
            let previous = sut.state
            let pagination = try #require(sut.send(.loadMore))
            let request = try await repository.waitForRequest(.fresh(page: 2, perPage: 20))
            sut.send(.onDisappear)
            #expect(sut.state == previous)
            try await repository.waitForCancellation(of: request)
            if lateSuccess {
                try await repository.succeed(request, posts: makePage("stale"))
            } else {
                try await repository.fail(request, error: NetworkError.cancelled)
            }
            await pagination.value
            #expect(sut.state == previous)

            let retry = try #require(sut.send(.loadMore))
            let retryRequest = try await repository.waitForRequest(.fresh(page: 2, perPage: 20), occurrence: 2)
            try await repository.succeed(retryRequest, posts: [])
            await retry.value
            #expect(sut.state.currentPage == 2)
        }
    }

    private func withViewModel(
        _ body: @MainActor (NewsViewModel, ControlledNewsRepository) async throws -> Void
    ) async throws {
        let repository = ControlledNewsRepository()
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
        _ repository: ControlledNewsRepository,
        hero: PostModel? = nil,
        posts: [PostModel]
    ) async throws {
        let task = try #require(sut.send(.onAppear))
        try await completeFirstPage(repository, hero: hero, posts: posts)
        await task.value
    }

    private func completeFirstPage(
        _ repository: ControlledNewsRepository,
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
