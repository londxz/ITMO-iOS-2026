import Foundation
import Combine
import OSLog

@MainActor
final class AuthorProfileViewModel: ObservableObject {
    @Published private(set) var state = AuthorState()

    private static let pageSize = 15

    private let authorID: String?
    private let username: String
    private let repository: any AuthorRepository
    private weak var router: (any AuthorRouting)?
    private let logger = Logger(subsystem: "NewsAppITMO", category: "AuthorProfileViewModel")

    private var firstPageTask = TaskSlot()
    private var nextPageTask = TaskSlot()
    private var firstPageGeneration = RequestGeneration()

    init(
        authorID: String?,
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
        case .dismissRefreshError:
            state.refreshError = nil
            return nil
        case .onDisappear:
            cancelLoading()
            return nil
        case .didSelectPost(let id):
            router?.openPost(id: id)
            return nil
        }
    }

    func refresh() async {
        await startInitialLoad().value
    }

    private func startInitialLoad() -> Task<Void, Never> {
        let generation = prepareInitialLoad()
        return firstPageTask.replace(with: Task { [weak self] in
            await self?.loadFirstPage(generation: generation)
        })
    }

    private func prepareInitialLoad() -> UUID {
        firstPageTask.cancel()
        nextPageTask.cancel()
        state.paginationLoad = .idle
        if state.author == nil {
            state.initialLoad = .loading
        }
        return firstPageGeneration.begin()
    }

    private func loadFirstPage(generation: UUID) async {
        defer { finishFirstPageLoad(generation) }
        let repository = repository
        let authorID = authorID
        let username = username
        let pageSize = Self.pageSize
        do {
            async let author = repository.fetchAuthor(id: authorID, username: username)
            async let posts = repository.fetchPosts(username: username, page: 1, perPage: pageSize)
            let (loadedAuthor, loadedPosts) = try await (author, posts)

            guard firstPageGeneration.isCurrent(generation) else { return }
            var newState = state
            newState.author = loadedAuthor
            newState.posts = loadedPosts
            newState.currentPage = 1
            newState.canLoadMore = loadedPosts.count == pageSize
            newState.initialLoad = .loaded
            newState.refreshError = nil
            state = newState
        } catch {
            guard firstPageGeneration.isCurrent(generation) else { return }
            guard !NetworkError.isCancellation(error) else {
                if state.initialLoad == .loading {
                    state.initialLoad = .idle
                }
                return
            }
            logger.error("first page load failed: \(String(describing: error), privacy: .public)")
            if state.author == nil {
                state.initialLoad = .failed(AppError(error))
            } else {
                state.refreshError = AppError(error)
            }
        }
    }

    private func startPagination() -> Task<Void, Never>? {
        guard state.initialLoad == .loaded,
              !firstPageGeneration.isActive,
              state.paginationLoad != .loading,
              state.canLoadMore
        else { return nil }

        state.paginationLoad = .loading
        return nextPageTask.replace(with: Task { [weak self] in
            await self?.loadNextPage()
        })
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
        firstPageTask.cancel()
        firstPageGeneration.invalidate()
        nextPageTask.cancel()
        if state.initialLoad == .loading {
            state.initialLoad = .idle
        }
        if state.paginationLoad == .loading {
            state.paginationLoad = .idle
        }
    }

    private func finishFirstPageLoad(_ generation: UUID) {
        if firstPageGeneration.end(generation) {
            firstPageTask.clear()
        }
    }
}
