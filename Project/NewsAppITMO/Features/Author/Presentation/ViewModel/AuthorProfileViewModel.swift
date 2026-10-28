import Foundation
import Combine
import OSLog

@MainActor
final class AuthorProfileViewModel: ObservableObject {
    @Published private(set) var state = AuthorState()

    private static let pageSize = 15

    private let authorID: String
    private let username: String
    private let repository: any AuthorRepository
    private weak var router: (any AuthorRouting)?
    private let logger = Logger(subsystem: "NewsAppITMO", category: "AuthorProfileViewModel")

    private var initialLoadTask: Task<Void, Never>?
    private var paginationTask: Task<Void, Never>?

    init(
        authorID: String,
        username: String,
        repository: any AuthorRepository,
        router: (any AuthorRouting)?
    ) {
        self.authorID = authorID
        self.username = username
        self.repository = repository
        self.router = router
    }

    @discardableResult
    func send(_ action: AuthorAction) -> Task<Void, Never>? {
        switch action {
        case .onAppear:
            guard state.initialLoad == .idle else { return nil }
            return startInitialLoad()
        case .refresh:
            return startInitialLoad()
        case .loadMore:
            return startPagination()
        case .onDisappear:
            cancelLoading()
            return nil
        case .didSelectPost(let id):
            router?.openPost(id: id)
            return nil
        }
    }

    private func startInitialLoad() -> Task<Void, Never> {
        initialLoadTask?.cancel()
        paginationTask?.cancel()
        state.paginationLoad = .idle
        if state.author == nil {
            state.initialLoad = .loading
        }
        let task = Task { [weak self] in
            guard let self else { return }
            await self.loadFirstPage()
        }
        initialLoadTask = task
        return task
    }

    private func loadFirstPage() async {
        let repository = repository
        let authorID = authorID
        let username = username
        let pageSize = Self.pageSize
        do {
            async let author = repository.fetchAuthor(id: authorID)
            async let posts = repository.fetchPosts(username: username, page: 1, perPage: pageSize)
            let (loadedAuthor, loadedPosts) = try await (author, posts)

            guard !Task.isCancelled else { return }
            var newState = state
            newState.author = loadedAuthor
            newState.posts = loadedPosts
            newState.currentPage = 1
            newState.canLoadMore = loadedPosts.count == pageSize
            newState.initialLoad = .loaded
            state = newState
        } catch {
            guard !Task.isCancelled else { return }
            logger.error("first page load failed: \(String(describing: error), privacy: .public)")
            if state.author == nil {
                state.initialLoad = .failed(AppError(error))
            }
        }
        initialLoadTask = nil
    }

    private func startPagination() -> Task<Void, Never>? {
        guard state.initialLoad == .loaded,
              initialLoadTask == nil,
              state.paginationLoad != .loading,
              state.canLoadMore
        else { return nil }

        state.paginationLoad = .loading
        let task = Task { [weak self] in
            guard let self else { return }
            await self.loadNextPage()
        }
        paginationTask = task
        return task
    }

    private func loadNextPage() async {
        let nextPage = state.currentPage + 1
        do {
            let page = try await repository.fetchPosts(
                username: username,
                page: nextPage,
                perPage: Self.pageSize
            )
            guard !Task.isCancelled else { return }

            var knownIDs = Set(state.posts.map(\.id))
            let newPosts = page.filter { knownIDs.insert($0.id).inserted }

            var newState = state
            newState.posts += newPosts
            newState.currentPage = nextPage
            newState.canLoadMore = page.count == Self.pageSize
            newState.paginationLoad = .loaded
            state = newState
        } catch {
            guard !Task.isCancelled else { return }
            logger.error("page \(nextPage) load failed: \(String(describing: error), privacy: .public)")
            state.paginationLoad = .failed(AppError(error))
        }
    }

    private func cancelLoading() {
        initialLoadTask?.cancel()
        initialLoadTask = nil
        paginationTask?.cancel()
        if state.initialLoad == .loading {
            state.initialLoad = .idle
        }
        if state.paginationLoad == .loading {
            state.paginationLoad = .idle
        }
    }
}
