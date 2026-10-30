import Combine
import Foundation

@MainActor
final class CommentsViewModel: ObservableObject {
    @Published private(set) var state = CommentsState()

    private let postID: String
    private let repository: any CommentsRepository
    private var loadTask = TaskSlot()
    private var loadGeneration = RequestGeneration()

    init(postID: String, repository: any CommentsRepository) {
        self.postID = postID
        self.repository = repository
    }

    deinit {
        loadTask.cancel()
    }

    @discardableResult
    func send(_ action: CommentsAction) -> Task<Void, Never>? {
        switch action {
        case .onAppear:
            guard state.loadState == .idle else { return nil }
            return startLoading()
        case .retry, .refresh:
            return startLoading()
        case .dismissRefreshError:
            state.refreshError = nil
            return nil
        case .onDisappear:
            loadTask.cancel()
            loadGeneration.invalidate()
            if state.loadState == .loading {
                state.loadState = state.isEmpty ? .idle : .loaded
            }
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
        let postID = postID
        do {
            let comments = try await repository.fetchComments(postID: postID)
            guard loadGeneration.isCurrent(generation) else { return }
            state = CommentsState(comments: comments, loadState: .loaded)
        } catch {
            guard loadGeneration.isCurrent(generation) else { return }
            if NetworkError.isCancellation(error) {
                state.loadState = state.isEmpty ? .idle : .loaded
            } else if state.isEmpty {
                state.loadState = .failed(AppError(error))
            } else {
                state.loadState = .loaded
                state.refreshError = AppError(error)
            }
        }
    }

    private func finishLoading(generation: UUID) {
        if loadGeneration.end(generation) {
            loadTask.clear()
        }
    }
}
