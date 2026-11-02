import Foundation
@testable import NewsAppITMO

/// Requests finish only when the test supplies a result. Cancellation is recorded,
/// but deliberately does not finish a request, so tests can deliver late responses.
actor MockNewsRepository: NewsRepository {
    enum Kind: Hashable, Sendable {
        case dayTop
        case fresh(page: Int, perPage: Int)
    }

    struct Request: Equatable, Sendable {
        let id: Int
        let kind: Kind
        let occurrence: Int
    }

    private enum Pending {
        case dayTop(CheckedContinuation<PostModel?, any Error>)
        case fresh(CheckedContinuation<[PostModel], any Error>)
    }

    private enum Event: Sendable {
        case requested(Request)
        case cancelled(Int)
    }

    enum Failure: Error {
        case timedOutWaitingForEvent
        case eventStreamEnded
        case unexpectedRequest
    }

    private(set) var requests: [Request] = []
    private var pending: [Int: Pending] = [:]
    private var events: [Event] = []
    private var observers: [UUID: AsyncStream<Event>.Continuation] = [:]
    private var isClosed = false

    func fetchDayTopPost() async throws -> PostModel? {
        guard !isClosed else { throw CancellationError() }
        let request = makeRequest(.dayTop)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending[request.id] = .dayTop(continuation)
                record(.requested(request))
            }
        } onCancel: {
            Task { await self.record(.cancelled(request.id)) }
        }
    }

    func fetchFreshPosts(page: Int, perPage: Int) async throws -> [PostModel] {
        guard !isClosed else { throw CancellationError() }
        let request = makeRequest(.fresh(page: page, perPage: perPage))
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending[request.id] = .fresh(continuation)
                record(.requested(request))
            }
        } onCancel: {
            Task { await self.record(.cancelled(request.id)) }
        }
    }

    func waitForRequest(_ kind: Kind, occurrence: Int = 1) async throws -> Request {
        let event = try await waitForEvent {
            guard case .requested(let request) = $0 else { return false }
            return request.kind == kind && request.occurrence == occurrence
        }
        guard case .requested(let request) = event else { throw Failure.unexpectedRequest }
        return request
    }

    func waitForCancellation(of request: Request) async throws {
        _ = try await waitForEvent {
            guard case .cancelled(let id) = $0 else { return false }
            return id == request.id
        }
    }

    func succeed(_ request: Request, hero: PostModel?) throws {
        guard case .dayTop(let continuation) = pending[request.id] else {
            throw Failure.unexpectedRequest
        }
        pending.removeValue(forKey: request.id)
        continuation.resume(returning: hero)
    }

    func succeed(_ request: Request, posts: [PostModel]) throws {
        guard case .fresh(let continuation) = pending[request.id] else {
            throw Failure.unexpectedRequest
        }
        pending.removeValue(forKey: request.id)
        continuation.resume(returning: posts)
    }

    func fail(_ request: Request, error: any Error) throws {
        guard let request = pending.removeValue(forKey: request.id) else {
            throw Failure.unexpectedRequest
        }
        resume(request, throwing: error)
    }

    /// Also cleans up continuations if a test assertion or event wait throws.
    func close() {
        isClosed = true
        let unfinished = pending.values
        pending.removeAll()
        for request in unfinished {
            resume(request, throwing: CancellationError())
        }
    }

    private func makeRequest(_ kind: Kind) -> Request {
        let request = Request(
            id: requests.count,
            kind: kind,
            occurrence: requests.filter { $0.kind == kind }.count + 1
        )
        requests.append(request)
        return request
    }

    private func record(_ event: Event) {
        events.append(event)
        for observer in observers.values {
            observer.yield(event)
        }
    }

    private func resume(_ pending: Pending, throwing error: any Error) {
        switch pending {
        case .dayTop(let continuation): continuation.resume(throwing: error)
        case .fresh(let continuation): continuation.resume(throwing: error)
        }
    }

    private func waitForEvent(
        matching predicate: @escaping @Sendable (Event) -> Bool
    ) async throws -> Event {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Event>.makeStream()
        observers[id] = continuation
        events.forEach { continuation.yield($0) }
        defer {
            observers.removeValue(forKey: id)
            continuation.finish()
        }

        // The timeout fails missing-request regressions instead of hanging the suite.
        // Cancelling an AsyncStream iterator also releases the losing group task.
        return try await withThrowingTaskGroup(of: Event.self) { group in
            group.addTask {
                for await event in stream where predicate(event) {
                    return event
                }
                throw Failure.eventStreamEnded
            }
            group.addTask {
                try await Task.sleep(for: .seconds(5))
                throw Failure.timedOutWaitingForEvent
            }
            defer { group.cancelAll() }
            guard let event = try await group.next() else { throw Failure.eventStreamEnded }
            return event
        }
    }
}

func makePost(_ id: String) -> PostModel {
    PostModel(
        id: id,
        title: "Post \(id)",
        summary: "Summary \(id)",
        bodyMarkdown: nil,
        publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
        coverImageURL: nil,
        readingTimeMinutes: 3,
        reactionsCount: 2,
        commentsCount: 1,
        tags: ["news"],
        author: AuthorModel(
            id: "author", username: "author", name: "Author",
            avatarURL: nil, bio: nil, location: nil, websiteURL: nil, joinedAt: nil
        ),
        webURL: nil
    )
}

func makePage(_ prefix: String = "post", count: Int = 20) -> [PostModel] {
    (0..<count).map { makePost("\(prefix)-\($0)") }
}
