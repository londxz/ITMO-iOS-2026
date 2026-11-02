//
//  NewsViewModel.swift
//  NewsAppITMO
//
//  Created by n.a.grebenkin on 08.10.2026.
//

import Foundation
import Combine
import OSLog

@MainActor
final class NewsViewModel: ObservableObject {
    @Published private(set) var state = NewsState()

    private static let pageSize = 20

    private let repository: any NewsRepository
    private weak var router: (any NewsRouting)?
    private let logger = Logger(subsystem: "NewsAppITMO", category: "NewsViewModel")

    private var initialLoadTask: Task<Void, Never>?
    private var paginationTask: Task<Void, Never>?
    private var initialLoadGeneration: UUID?

    init(repository: any NewsRepository, router: (any NewsRouting)?) {
        self.repository = repository
        self.router = router
    }

    @discardableResult
    func send(_ action: NewsAction) -> Task<Void, Never>? {
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
        case .didSelectAuthor(let id, let username):
            router?.openAuthor(id: id, username: username)
            return nil
        }
    }

    func refresh() async {
        let generation = prepareInitialLoad()
        await loadFirstPage(generation: generation)
    }

    private func startInitialLoad() -> Task<Void, Never> {
        let generation = prepareInitialLoad()
        let task = Task { [weak self] in
            guard let self else { return }
            await self.loadFirstPage(generation: generation)
        }
        initialLoadTask = task
        return task
    }

    private func prepareInitialLoad() -> UUID {
        initialLoadTask?.cancel()
        initialLoadTask = nil
        paginationTask?.cancel()
        paginationTask = nil
        state.paginationLoad = .idle
        if state.isEmpty {
            state.initialLoad = .loading
        }
        let generation = UUID()
        initialLoadGeneration = generation
        return generation
    }

    private func loadFirstPage(generation: UUID) async {
        defer { finishInitialLoad(generation: generation) }
        let repository = repository
        let pageSize = Self.pageSize
        do {
            async let dayTopRequest = repository.fetchDayTopPost()
            async let fresh = repository.fetchFreshPosts(page: 1, perPage: pageSize)

            let posts = try await fresh
            let heroPost: PostModel?
            do {
                heroPost = try await dayTopRequest
            } catch {
                guard !Task.isCancelled else { throw error }
                logger.error("day top load failed: \(String(describing: error), privacy: .public)")
                heroPost = nil
            }

            guard isCurrentInitialLoad(generation) else { return }
            var newState = state
            newState.heroPost = heroPost
            newState.posts = posts.filter { $0.id != heroPost?.id }
            newState.currentPage = 1
            newState.canLoadMore = posts.count == pageSize
            newState.initialLoad = .loaded
            state = newState
        } catch {
            guard isCurrentInitialLoad(generation) else { return }
            logger.error("first page load failed: \(String(describing: error), privacy: .public)")
            if state.isEmpty {
                state.initialLoad = .failed(AppError(error))
            }
        }
    }

    private func startPagination() -> Task<Void, Never>? {
        guard state.initialLoad == .loaded,
              initialLoadGeneration == nil,
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
            let page = try await repository.fetchFreshPosts(page: nextPage, perPage: Self.pageSize)
            guard !Task.isCancelled else { return }

            var knownIDs = Set(state.posts.map(\.id))
            if let heroID = state.heroPost?.id {
                knownIDs.insert(heroID)
            }
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
        initialLoadGeneration = nil
        paginationTask?.cancel()
        paginationTask = nil
        if state.initialLoad == .loading {
            state.initialLoad = .idle
        }
        if state.paginationLoad == .loading {
            state.paginationLoad = .idle
        }
    }

    private func isCurrentInitialLoad(_ generation: UUID) -> Bool {
        initialLoadGeneration == generation && !Task.isCancelled
    }

    private func finishInitialLoad(generation: UUID) {
        guard initialLoadGeneration == generation else { return }
        initialLoadGeneration = nil
        initialLoadTask = nil
    }
}
