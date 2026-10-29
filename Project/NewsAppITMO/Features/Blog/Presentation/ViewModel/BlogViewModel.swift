import Foundation
import Combine
import OSLog

@MainActor
final class BlogViewModel: ObservableObject {
    @Published private(set) var state = BlogState()

    private static let pageSize = 15

    private let repository: any BlogRepository
    private weak var router: (any BlogRouting)?
    private let logger = Logger(subsystem: "NewsAppITMO", category: "BlogViewModel")

    private var firstPageTask = TaskSlot()
    private var nextPageTask = TaskSlot()
    private var firstPageGeneration = RequestGeneration()

    init(repository: any BlogRepository, router: (any BlogRouting)?) {
        self.repository = repository
        self.router = router
    }

    @discardableResult
    func send(_ action: BlogAction) -> Task<Void, Never>? {
        switch action {
        case .onAppear:
            guard state.initialLoad == .idle else { return nil }
            return startFirstPageLoad(reloadTags: true)
        case .refresh:
            return startFirstPageLoad(reloadTags: true)
        case .loadMore:
            return startPagination()
        case .dismissRefreshError:
            state.refreshError = nil
            return nil
        case .selectTag(let tag):
            guard tag != state.selectedTag else { return nil }
            state.selectedTag = tag
            return restartFeed()
        case .selectSort(let sort):
            guard sort != state.selectedSort else { return nil }
            state.selectedSort = sort
            return restartFeed()
        case .onDisappear:
            cancelLoading()
            return nil
        case .didSelectPost(let id):
            router?.openPost(id: id)
            return nil
        case .didSelectAuthor(let id, let username):
            router?.openAuthor(id: id, username: username)
            return nil
        }
    }

    func refresh() async {
        await startFirstPageLoad(reloadTags: true).value
    }

    private func restartFeed() -> Task<Void, Never> {
        var newState = state
        newState.posts = []
        newState.currentPage = 1
        newState.canLoadMore = true
        newState.initialLoad = .loading
        state = newState
        return startFirstPageLoad(reloadTags: state.tags.isEmpty)
    }

    private func startFirstPageLoad(reloadTags: Bool) -> Task<Void, Never> {
        let generation = prepareFirstPageLoad()
        return firstPageTask.replace(with: Task { [weak self] in
            await self?.loadFirstPage(generation: generation, reloadTags: reloadTags)
        })
    }

    private func prepareFirstPageLoad() -> UUID {
        firstPageTask.cancel()
        nextPageTask.cancel()
        state.paginationLoad = .idle
        if state.initialLoad != .loaded {
            state.initialLoad = .loading
        }
        return firstPageGeneration.begin()
    }

    private func loadFirstPage(generation: UUID, reloadTags: Bool) async {
        defer { finishFirstPageLoad(generation) }
        let repository = repository
        let tag = state.selectedTag?.name
        let sort = state.selectedSort
        let pageSize = Self.pageSize

        async let firstPage = repository.fetchArticles(tag: tag, sort: sort, page: 1, perPage: pageSize)
        var tags: [BlogTagModel]?
        if reloadTags {
            do {
                tags = try await repository.fetchTags()
            } catch where !Task.isCancelled {
                logger.error("tags load failed: \(String(describing: error), privacy: .public)")
            } catch {}
        }

        do {
            let posts = try await firstPage
            guard firstPageGeneration.isCurrent(generation) else { return }

            var newState = state
            if let tags {
                newState.tags = Self.tags(tags, keeping: newState.selectedTag)
            }
            newState.posts = posts
            newState.currentPage = 1
            newState.canLoadMore = posts.count == pageSize
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
            if let tags {
                state.tags = Self.tags(tags, keeping: state.selectedTag)
            }
            if state.isEmpty {
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
        let tag = state.selectedTag?.name
        let sort = state.selectedSort
        do {
            let page = try await repository.fetchArticles(
                tag: tag,
                sort: sort,
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

    private static func tags(
        _ tags: [BlogTagModel],
        keeping selectedTag: BlogTagModel?
    ) -> [BlogTagModel] {
        guard let selectedTag, !tags.contains(selectedTag) else { return tags }
        return [selectedTag] + tags
    }
}
