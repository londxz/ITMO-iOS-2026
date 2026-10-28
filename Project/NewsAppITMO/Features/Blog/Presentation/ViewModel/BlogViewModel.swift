//
//  BlogViewModel.swift
//  NewsAppITMO
//
//  Created by n.a.grebenkin on 28.10.2026.
//

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

    private var initialLoadTask: Task<Void, Never>?
    private var paginationTask: Task<Void, Never>?
    // меняется на каждую новую выдачу (refresh, тег, сортировка):
    // ответ, пришедший для старого поколения, отбрасывается
    private var generationID = UUID()

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

    // MARK: - Первая страница

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
        initialLoadTask?.cancel()
        paginationTask?.cancel()
        let generation = UUID()
        generationID = generation
        state.paginationLoad = .idle
        // при pull-to-refresh старая лента остаётся на экране до ответа
        if state.initialLoad != .loaded {
            state.initialLoad = .loading
        }
        let task = Task { [weak self] in
            guard let self else { return }
            await self.loadFirstPage(generation: generation, reloadTags: reloadTags)
        }
        initialLoadTask = task
        return task
    }

    private func loadFirstPage(generation: UUID, reloadTags: Bool) async {
        let repository = repository
        let tag = state.selectedTag?.name
        let sort = state.selectedSort
        let pageSize = Self.pageSize

        // статьи стартуют сразу, теги грузятся параллельно с ними
        async let firstPage = repository.fetchArticles(tag: tag, sort: sort, page: 1, perPage: pageSize)
        var tags: [BlogTagModel]?
        if reloadTags {
            do {
                tags = try await repository.fetchTags()
            } catch where !Task.isCancelled {
                // без тегов лента всё равно работает, в карусели останется «Все»
                logger.error("tags load failed: \(String(describing: error), privacy: .public)")
            } catch {}
        }

        do {
            let posts = try await firstPage
            guard isCurrent(generation) else { return }

            var newState = state
            if let tags {
                newState.tags = Self.tags(tags, keeping: newState.selectedTag)
            }
            newState.posts = posts
            newState.currentPage = 1
            newState.canLoadMore = posts.count == pageSize
            newState.initialLoad = .loaded
            state = newState
        } catch {
            guard isCurrent(generation) else { return }
            logger.error("first page load failed: \(String(describing: error), privacy: .public)")
            if let tags {
                state.tags = Self.tags(tags, keeping: state.selectedTag)
            }
            // если упал refresh, а лента уже есть — оставляем её на экране
            if state.isEmpty {
                state.initialLoad = .failed(AppError(error))
            }
        }
        initialLoadTask = nil
    }

    // MARK: - Пагинация

    private func startPagination() -> Task<Void, Never>? {
        guard state.initialLoad == .loaded,
              initialLoadTask == nil,
              state.paginationLoad != .loading,
              state.canLoadMore
        else { return nil }

        state.paginationLoad = .loading
        let generation = generationID
        let task = Task { [weak self] in
            guard let self else { return }
            await self.loadNextPage(generation: generation)
        }
        paginationTask = task
        return task
    }

    private func loadNextPage(generation: UUID) async {
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
            guard isCurrent(generation) else { return }

            // лента сдвигается, пока её листают, поэтому страницы могут пересекаться
            var knownIDs = Set(state.posts.map(\.id))
            let newPosts = page.filter { knownIDs.insert($0.id).inserted }

            var newState = state
            newState.posts += newPosts
            newState.currentPage = nextPage
            newState.canLoadMore = page.count == Self.pageSize
            newState.paginationLoad = .loaded
            state = newState
        } catch {
            guard isCurrent(generation) else { return }
            logger.error("page \(nextPage) load failed: \(String(describing: error), privacy: .public)")
            state.paginationLoad = .failed(AppError(error))
        }
    }

    // MARK: - Уход с экрана

    private func cancelLoading() {
        initialLoadTask?.cancel()
        initialLoadTask = nil
        paginationTask?.cancel()
        generationID = UUID()
        if state.initialLoad == .loading {
            state.initialLoad = .idle
        }
        if state.paginationLoad == .loading {
            state.paginationLoad = .idle
        }
    }

    private func isCurrent(_ generation: UUID) -> Bool {
        generation == generationID && !Task.isCancelled
    }

    // выбранный тег не должен пропасть из карусели, если сервер его больше не вернул
    private static func tags(
        _ tags: [BlogTagModel],
        keeping selectedTag: BlogTagModel?
    ) -> [BlogTagModel] {
        guard let selectedTag, !tags.contains(selectedTag) else { return tags }
        return [selectedTag] + tags
    }
}
