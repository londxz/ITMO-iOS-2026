import Combine
import Foundation

@MainActor
final class CommentsViewModel: ObservableObject {
    @Published private(set) var state = CommentsState()

    private let postID: String
    private let repository: any CommentsRepository
    private var loadTask: Task<Void, Never>?
    private var loadGeneration: UUID?

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
            loadGeneration = nil
            if state.loadState == .loading {
                state.loadState = state.isEmpty ? .idle : .loaded
            }
            return nil
        }
    }

    func refresh() async {
        let generation = prepareLoading()
        await load(generation: generation)
    }

    private func startLoading() -> Task<Void, Never> {
        let generation = prepareLoading()
        let task = Task { [weak self] in
            guard let self else { return }
            await self.load(generation: generation)
        }
        loadTask = task
        return task
    }

    private func prepareLoading() -> UUID {
        loadTask?.cancel()
        loadTask = nil
        state.loadState = .loading
        let generation = UUID()
        loadGeneration = generation
        return generation
    }

    private func load(generation: UUID) async {
        defer { finishLoading(generation: generation) }
        let repository = repository
        let postID = postID
        do {
            let comments = try await repository.fetchComments(postID: postID)
            guard isCurrentLoad(generation) else { return }
            state = CommentsState(comments: comments, loadState: .loaded)
        } catch {
            guard isCurrentLoad(generation) else { return }
            if error is CancellationError || error as? NetworkError == .cancelled
                || (error as? URLError)?.code == .cancelled {
                state.loadState = state.isEmpty ? .idle : .loaded
            } else {
                state.loadState = .failed(AppError(error))
            }
        }
    }

    private func isCurrentLoad(_ generation: UUID) -> Bool {
        loadGeneration == generation && !Task.isCancelled
    }

    private func finishLoading(generation: UUID) {
        guard loadGeneration == generation else { return }
        loadGeneration = nil
        loadTask = nil
    }
}
