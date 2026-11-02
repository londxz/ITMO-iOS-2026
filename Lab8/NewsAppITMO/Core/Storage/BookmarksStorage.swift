//
//  BookmarksStorage.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 27.10.2026.
//

import Foundation

protocol BookmarksStorage: Sendable {
    func getBookmarks() async throws -> [PostModel]
    func isBookmarked(id: String) async -> Bool
    func save(post: PostModel) async throws
    func remove(id: String) async throws
    func observeBookmarks() -> AsyncStream<[PostModel]>
}

actor FileBookmarksStorage: BookmarksStorage {
    private let fileManager: FileManager
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var cachedBookmarks: [PostModel]?
    private var observers: [UUID: AsyncStream<[PostModel]>.Continuation] = [:]

    init(
        fileManager: FileManager = .default,
        fileURL: URL? = nil
    ) {
        self.fileManager = fileManager

        if let fileURL {
            self.fileURL = fileURL
        } else {
            let applicationSupportURL = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? fileManager.temporaryDirectory
            self.fileURL = applicationSupportURL.appendingPathComponent(
                "bookmarks.json",
                isDirectory: false
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    func getBookmarks() throws -> [PostModel] {
        try loadBookmarksIfNeeded()
    }

    func isBookmarked(id: String) -> Bool {
        guard let bookmarks = try? loadBookmarksIfNeeded() else { return false }
        return bookmarks.contains { $0.id == id }
    }

    func save(post: PostModel) throws {
        var bookmarks = try loadBookmarksIfNeeded()
        bookmarks.removeAll { $0.id == post.id }
        bookmarks.insert(post, at: 0)

        try persist(bookmarks)
        cachedBookmarks = bookmarks
        notifyObservers(with: bookmarks)
    }

    func remove(id: String) throws {
        var bookmarks = try loadBookmarksIfNeeded()
        let initialCount = bookmarks.count
        bookmarks.removeAll { $0.id == id }

        guard bookmarks.count != initialCount else { return }

        try persist(bookmarks)
        cachedBookmarks = bookmarks
        notifyObservers(with: bookmarks)
    }

    nonisolated func observeBookmarks() -> AsyncStream<[PostModel]> {
        let observerID = UUID()

        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let registrationTask = Task {
                await self.addObserver(
                    id: observerID,
                    continuation: continuation
                )
            }

            continuation.onTermination = { [weak self] _ in
                registrationTask.cancel()
                Task {
                    await self?.removeObserver(id: observerID)
                }
            }
        }
    }

    private func loadBookmarksIfNeeded() throws -> [PostModel] {
        if let cachedBookmarks {
            return cachedBookmarks
        }

        guard fileManager.fileExists(atPath: fileURL.path) else {
            cachedBookmarks = []
            return []
        }

        let data = try Data(contentsOf: fileURL)
        let bookmarks = try decoder.decode([PostModel].self, from: data)
        cachedBookmarks = bookmarks
        return bookmarks
    }

    private func persist(_ bookmarks: [PostModel]) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let data = try encoder.encode(bookmarks)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func addObserver(
        id: UUID,
        continuation: AsyncStream<[PostModel]>.Continuation
    ) {
        guard !Task.isCancelled else { return }

        do {
            let bookmarks = try loadBookmarksIfNeeded()
            observers[id] = continuation
            continuation.yield(bookmarks)
        } catch {
            continuation.finish()
        }
    }

    private func removeObserver(id: UUID) {
        observers[id] = nil
    }

    private func notifyObservers(with bookmarks: [PostModel]) {
        observers.values.forEach { continuation in
            continuation.yield(bookmarks)
        }
    }
}
