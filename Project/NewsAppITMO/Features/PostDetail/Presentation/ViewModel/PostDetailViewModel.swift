import Combine
import Foundation

@MainActor
final class PostDetailViewModel: ObservableObject {
    @Published private(set) var state = PostDetailState()

    private let postID: String
    private let repository: any PostDetailRepository
    private let bookmarksStorage: any BookmarksStorage
    private weak var router: (any PostDetailRouting)?
    private var loadTask: Task<Void, Never>?
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
        loadTask?.cancel()
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
            loadTask?.cancel()
            loadTask = nil
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
        }
    }

    private func startLoading() -> Task<Void, Never> {
        loadTask?.cancel()
        state.loadState = .loading
        let repository = repository
        let storage = bookmarksStorage
        let postID = postID
        let revision = bookmarkRevision

        let task = Task { [weak self] in
            let savedPost: PostModel?
            do {
                savedPost = try await storage.getBookmarks().first { $0.id == postID }
                guard !Task.isCancelled else { return }
                if let self {
                    if self.bookmarkRevision == revision && self.bookmarkTask == nil {
                        self.state.isBookmarked = savedPost != nil
                    }
                    if self.state.post == nil, Self.hasBody(savedPost) {
                        self.state.post = savedPost
                    }
                }
            } catch {
                // A damaged local file must not prevent a successful network load.
                savedPost = nil
            }
            guard !Task.isCancelled else { return }

            do {
                let post = try await repository.fetchPost(id: postID)
                guard !Task.isCancelled, let self else { return }
                self.state.post = post
                self.state.loadState = .loaded
                self.loadTask = nil
            } catch {
                guard !Task.isCancelled, let self else { return }
                if Self.isCancellation(error) {
                    self.state.loadState = self.state.post == nil ? .idle : .loaded
                } else if Self.hasBody(savedPost) {
                    // Keep an already-visible, newer version when refreshing.
                    if self.state.post == nil { self.state.post = savedPost }
                    self.state.loadState = .loaded
                } else {
                    self.state.loadState = .failed(AppError(error))
                }
                self.loadTask = nil
            }
        }
        loadTask = task
        return task
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
                if Self.isCancellation(error) {
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
        guard state.post != nil, bookmarkTask == nil, loadTask == nil else { return nil }
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

    private static func isCancellation(_ error: any Error) -> Bool {
        error is CancellationError || error as? NetworkError == .cancelled
            || (error as? URLError)?.code == .cancelled
    }
}
