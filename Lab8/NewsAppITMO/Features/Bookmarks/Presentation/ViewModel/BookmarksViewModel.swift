import Combine
import Foundation

@MainActor
final class BookmarksViewModel: ObservableObject {
    @Published private(set) var state = BookmarksState()

    private let storage: any BookmarksStorage
    private weak var router: (any BookmarksRouting)?
    private var observationTask: Task<Void, Never>?
    private var mutationTask: Task<Void, Never>?

    init(storage: any BookmarksStorage, router: (any BookmarksRouting)?) {
        self.storage = storage
        self.router = router
    }

    deinit {
        observationTask?.cancel()
        mutationTask?.cancel()
    }

    @discardableResult
    func send(_ action: BookmarksAction) -> Task<Void, Never>? {
        switch action {
        case .onAppear:
            guard observationTask == nil else { return nil }
            return startObserving()
        case .retry:
            observationTask?.cancel()
            return startObserving()
        case .onDisappear:
            observationTask?.cancel()
            observationTask = nil
            mutationTask?.cancel()
            mutationTask = nil
            state.deletingID = nil
            if state.loadState == .loading { state.loadState = .idle }
            return nil
        case .searchTextChanged(let text):
            state.searchText = text
            return nil
        case .delete(let id):
            return delete(id: id)
        case .didSelectPost(let id):
            router?.openPost(id: id)
            return nil
        case .dismissMessage:
            state.message = nil
            return nil
        }
    }

    private func startObserving() -> Task<Void, Never> {
        if state.isEmpty { state.loadState = .loading }
        let storage = storage
        let task = Task { [weak self] in
            guard !Task.isCancelled else { return }
            var receivedValue = false
            for await bookmarks in storage.observeBookmarks() {
                guard !Task.isCancelled else { return }
                receivedValue = true
                self?.state.bookmarks = bookmarks
                self?.state.loadState = .loaded
            }
            guard !Task.isCancelled else { return }
            if !receivedValue {
                // FileBookmarksStorage finishes its stream if the initial read
                // fails. Read explicitly to obtain the underlying error.
                do {
                    let bookmarks = try await storage.getBookmarks()
                    guard !Task.isCancelled else { return }
                    self?.state.bookmarks = bookmarks
                    self?.state.loadState = .loaded
                } catch {
                    guard !Task.isCancelled else { return }
                    if !Self.isCancellation(error) {
                        self?.state.loadState = .failed(AppError(error))
                    } else {
                        self?.state.loadState = .idle
                    }
                }
            }
            self?.observationTask = nil
        }
        observationTask = task
        return task
    }

    private func delete(id: String) -> Task<Void, Never>? {
        guard mutationTask == nil, state.bookmarks.contains(where: { $0.id == id }) else { return nil }
        state.deletingID = id
        let storage = storage
        let task = Task { [weak self] in
            do {
                try Task.checkCancellation()
                try await storage.remove(id: id)
                guard !Task.isCancelled else { return }
                // The stream publishes the persisted list; never remove rows
                // optimistically before the file write succeeds.
            } catch {
                guard !Task.isCancelled else { return }
                if !Self.isCancellation(error) {
                    self?.state.message = "Не удалось удалить статью из закладок. Попробуйте ещё раз."
                }
            }
            self?.state.deletingID = nil
            self?.mutationTask = nil
        }
        mutationTask = task
        return task
    }

    private static func isCancellation(_ error: any Error) -> Bool {
        error is CancellationError || error as? NetworkError == .cancelled
            || (error as? URLError)?.code == .cancelled
    }
}
