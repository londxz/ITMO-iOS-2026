import Combine
import Foundation

@MainActor
final class CommentsViewModel: ObservableObject {
    @Published private(set) var state = CommentsState()

    private let postID: String
    private let repository: any CommentsRepository
    private var loadTask: Task<Void, Never>?

    init(postID: String, repository: any CommentsRepository) {
        self.postID = postID
        self.repository = repository
    }

    deinit {
        loadTask?.cancel()
    }

    @discardableResult
    func send(_ action: CommentsAction) -> Task<Void, Never>? {
        switch action {
        case .onAppear:
            guard state.loadState == .idle else { return nil }
            return startLoading()
        case .retry, .refresh:
            return startLoading()
        case .onDisappear:
            loadTask?.cancel()
            loadTask = nil
            if state.loadState == .loading {
                state.loadState = state.isEmpty ? .idle : .loaded
            }
            return nil
        }
    }

    private func startLoading() -> Task<Void, Never> {
        loadTask?.cancel()
        state.loadState = .loading

        let repository = repository
        let postID = postID
        let task = Task { [weak self] in
            do {
                let comments = try await repository.fetchComments(postID: postID)
                guard !Task.isCancelled, let self else { return }

                self.state = CommentsState(comments: comments, loadState: .loaded)
                self.loadTask = nil
            } catch {
                guard !Task.isCancelled, let self else { return }

                if error is CancellationError || error as? NetworkError == .cancelled
                    || (error as? URLError)?.code == .cancelled {
                    self.state.loadState = self.state.isEmpty ? .idle : .loaded
                } else {
                    self.state.loadState = .failed(AppError(error))
                }
                self.loadTask = nil
            }
        }
        loadTask = task
        return task
    }
}
