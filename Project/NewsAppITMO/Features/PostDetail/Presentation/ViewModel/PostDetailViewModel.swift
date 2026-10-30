import Combine
import Foundation

@MainActor
final class PostDetailViewModel: ObservableObject {
    @Published private(set) var state = PostDetailState()

    private let postID: String
    private let repository: any PostDetailRepository
    private let bookmarksStorage: any BookmarksStorage
    private weak var router: (any PostDetailRouting)?
    private var loadTask = TaskSlot()
    private var loadGeneration = RequestGeneration()
    private var bookmarkTask: Task<Void, Never>?
    private var bookmarkWriteStarted = false
    private var bookmarkRevision = 0

    init(
        postID: String,
        repository: any PostDetailRepository,
        bookmarksStorage: any BookmarksStorage,
        router: (any PostDetailRouting)?
    ) {
        self.postID = postID
        self.repository = repository
        self.bookmarksStorage = bookmarksStorage
        self.router = router
    }

    deinit {
        loadTask.cancel()
        bookmarkTask?.cancel()
    }

    @discardableResult
    func send(_ action: PostDetailAction) -> Task<Void, Never>? {
        switch action {
        case .onAppear:
            if state.loadState == .idle { return startLoading() }
            return synchronizeBookmark()
        case .retry, .refresh:
            return startLoading()
        case .toggleBookmark:
            return toggleBookmark()
        case .onDisappear:
            loadTask.cancel()
            loadGeneration.invalidate()
            if state.loadState == .loading {
                state.loadState = state.post == nil ? .idle : .loaded
            }
            // Once an atomic file write starts, let it finish. Cancelling then
            // could leave the visible bookmark state behind the persisted file.
            if !bookmarkWriteStarted {
                bookmarkTask?.cancel()
                bookmarkTask = nil
                state.bookmarkUpdate = .idle
            }
            return nil
        case .didSelectAuthor:
            if let author = state.post?.author {
                router?.openAuthor(id: author.id, username: author.username)
            }
            return nil
        case .didSelectComments:
            router?.openComments(postID: postID)
            return nil
        case .dismissMessage:
            state.message = nil
            return nil
        case .dismissRefreshError:
            state.refreshError = nil
            return nil
        }
    }

    func refresh() async {
        await startLoading().value
    }

    private func startLoading() -> Task<Void, Never> {
        let generation = prepareLoading()
        return loadTask.replace(with: Task { [weak self] in
            await self?.load(generation: generation)
        })
    }

    private func prepareLoading() -> UUID {
        loadTask.cancel()
        state.loadState = .loading
        return loadGeneration.begin()
    }

    private func load(generation: UUID) async {
        defer { finishLoading(generation: generation) }
        let repository = repository
        let storage = bookmarksStorage
        let postID = postID
        let revision = bookmarkRevision
        let hadVisiblePost = state.post != nil

        let savedPost: PostModel?
        do {
            savedPost = try await storage.getBookmarks().first { $0.id == postID }
            guard loadGeneration.isCurrent(generation) else { return }
            if bookmarkRevision == revision && bookmarkTask == nil {
                state.isBookmarked = savedPost != nil
            }
            if state.post == nil, Self.hasBody(savedPost) {
                state.post = savedPost
            }
        } catch {
            // A damaged local file must not prevent a successful network load.
            savedPost = nil
        }
        guard loadGeneration.isCurrent(generation) else { return }

        do {
            let post = try await repository.fetchPost(id: postID)
            guard loadGeneration.isCurrent(generation) else { return }
            state.post = post
            state.loadState = .loaded
            state.refreshError = nil
        } catch {
            guard loadGeneration.isCurrent(generation) else { return }
            if NetworkError.isCancellation(error) {
                state.loadState = state.post == nil ? .idle : .loaded
            } else if hadVisiblePost {
                state.loadState = .loaded
                state.refreshError = AppError(error)
            } else if Self.hasBody(savedPost) {
                if state.post == nil {
                    state.post = savedPost
                }
                state.loadState = .loaded
            } else {
                state.loadState = .failed(AppError(error))
            }
        }
    }

    private func finishLoading(generation: UUID) {
        if loadGeneration.end(generation) {
            loadTask.clear()
        }
    }

    private func toggleBookmark() -> Task<Void, Never>? {
        guard let post = state.post, bookmarkTask == nil,
              state.bookmarkUpdate != .loading else { return nil }
        bookmarkRevision += 1
        state.bookmarkUpdate = .loading
        let shouldRemove = state.isBookmarked
        let storage = bookmarksStorage

        let task = Task { [weak self] in
            guard !Task.isCancelled else { return }
            self?.bookmarkWriteStarted = true
            do {
                if shouldRemove {
                    try await storage.remove(id: post.id)
                } else {
                    try await storage.save(post: post)
                }
                guard !Task.isCancelled, let self else { return }
                self.state.isBookmarked = !shouldRemove
                self.state.bookmarkUpdate = .loaded
            } catch {
                guard !Task.isCancelled, let self else { return }
                if NetworkError.isCancellation(error) {
                    self.state.bookmarkUpdate = .idle
                } else {
                    self.state.bookmarkUpdate = .failed(AppError(error))
                    self.state.message = shouldRemove
                        ? "Не удалось удалить статью из закладок. Попробуйте ещё раз."
                        : "Не удалось сохранить статью. Попробуйте ещё раз."
                }
            }
            self?.bookmarkWriteStarted = false
            self?.bookmarkTask = nil
        }
        bookmarkTask = task
        return task
    }

    private func synchronizeBookmark() -> Task<Void, Never>? {
        guard state.post != nil, bookmarkTask == nil, !loadTask.isRunning else { return nil }
        let storage = bookmarksStorage
        let postID = postID
        state.bookmarkUpdate = .loading
        let task = Task { [weak self] in
            let bookmarks = try? await storage.getBookmarks()
            guard !Task.isCancelled, let self else { return }
            if let bookmarks {
                self.state.isBookmarked = bookmarks.contains { $0.id == postID }
            }
            self.state.bookmarkUpdate = .idle
            self.bookmarkTask = nil
        }
        bookmarkTask = task
        return task
    }

    private static func hasBody(_ post: PostModel?) -> Bool {
        guard let body = post?.bodyMarkdown else { return false }
        return !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
