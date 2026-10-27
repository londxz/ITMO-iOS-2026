//
//  ImageCache.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 27.10.2026.
//

import CryptoKit
import Foundation

protocol ImageCache: Sendable {
    func data(for url: URL) async throws -> Data
    func clearCache() async throws
}

actor ImageCacheImpl: ImageCache {
    private static let defaultDiskLimitBytes = 150 * 1024 * 1024
    private static let defaultMemoryLimitBytes = 50 * 1024 * 1024

    private struct InFlightRequest {
        let task: Task<Data, any Error>
        var waiters: Set<UUID>
    }

    private struct DiskEntry {
        let url: URL
        let size: Int
        let lastAccessedAt: Date
    }

    private let session: URLSession
    private let fileManager: FileManager
    private let directoryURL: URL
    private let diskLimitBytes: Int
    private let memoryCache = NSCache<NSURL, NSData>()

    private var inFlightRequests: [URL: InFlightRequest] = [:]

    init(
        session: URLSession = .shared,
        fileManager: FileManager = .default,
        directoryURL: URL? = nil,
        diskLimitBytes: Int = ImageCacheImpl.defaultDiskLimitBytes,
        memoryLimitBytes: Int = ImageCacheImpl.defaultMemoryLimitBytes
    ) {
        self.session = session
        self.fileManager = fileManager
        self.diskLimitBytes = diskLimitBytes

        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let cachesURL = fileManager.urls(
                for: .cachesDirectory,
                in: .userDomainMask
            ).first ?? fileManager.temporaryDirectory
            self.directoryURL = cachesURL.appendingPathComponent(
                "ImageCache",
                isDirectory: true
            )
        }

        memoryCache.totalCostLimit = memoryLimitBytes
    }

    func data(for url: URL) async throws -> Data {
        if let cachedData = memoryCache.object(forKey: url as NSURL) {
            return cachedData as Data
        }

        if let cachedData = loadFromDisk(for: url) {
            storeInMemory(cachedData, for: url)
            return cachedData
        }

        let waiterID = UUID()
        let requestTask = joinOrCreateRequest(for: url, waiterID: waiterID)

        do {
            let data = try await withTaskCancellationHandler {
                let data = try await requestTask.value
                try Task.checkCancellation()
                return data
            } onCancel: {
                Task {
                    await self.cancelWaiter(waiterID, for: url)
                }
            }

            guard inFlightRequests.removeValue(forKey: url) != nil else {
                return data
            }

            storeInMemory(data, for: url)
            storeOnDisk(data, for: url)
            trimDiskCacheIfNeeded()
            return data
        } catch {
            releaseWaiter(waiterID, for: url)

            if error is CancellationError {
                throw NetworkError.cancelled
            }
            if let urlError = error as? URLError {
                if urlError.code == .cancelled {
                    throw NetworkError.cancelled
                }
                throw NetworkError.transport(urlError.code)
            }
            throw error
        }
    }

    func clearCache() throws {
        inFlightRequests.values.forEach { $0.task.cancel() }
        inFlightRequests.removeAll()
        memoryCache.removeAllObjects()

        if fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.removeItem(at: directoryURL)
        }
        try createCacheDirectoryIfNeeded()
    }

    private func joinOrCreateRequest(
        for url: URL,
        waiterID: UUID
    ) -> Task<Data, any Error> {
        if var request = inFlightRequests[url] {
            request.waiters.insert(waiterID)
            inFlightRequests[url] = request
            return request.task
        }

        let session = session
        let task = Task<Data, any Error> {
            try Task.checkCancellation()
            let (data, response) = try await session.data(from: url)
            try Task.checkCancellation()

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverUnavailable(
                    statusCode: httpResponse.statusCode
                )
            }
            guard !data.isEmpty else {
                throw NetworkError.invalidResponse
            }
            return data
        }

        inFlightRequests[url] = InFlightRequest(
            task: task,
            waiters: [waiterID]
        )
        return task
    }

    private func cancelWaiter(_ waiterID: UUID, for url: URL) {
        releaseWaiter(waiterID, for: url)
    }

    private func releaseWaiter(_ waiterID: UUID, for url: URL) {
        guard var request = inFlightRequests[url] else { return }
        request.waiters.remove(waiterID)

        if request.waiters.isEmpty {
            request.task.cancel()
            inFlightRequests[url] = nil
        } else {
            inFlightRequests[url] = request
        }
    }

    private func storeInMemory(_ data: Data, for url: URL) {
        memoryCache.setObject(
            data as NSData,
            forKey: url as NSURL,
            cost: data.count
        )
    }

    private func loadFromDisk(for url: URL) -> Data? {
        let fileURL = cachedFileURL(for: url)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }

        do {
            let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
            guard !data.isEmpty else {
                try? fileManager.removeItem(at: fileURL)
                return nil
            }

            try? fileManager.setAttributes(
                [.modificationDate: Date()],
                ofItemAtPath: fileURL.path
            )
            return data
        } catch {
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
    }

    private func storeOnDisk(_ data: Data, for url: URL) {
        do {
            try createCacheDirectoryIfNeeded()
            try data.write(to: cachedFileURL(for: url), options: .atomic)
        } catch {
            // Disk caching is best-effort. The downloaded image remains in memory.
        }
    }

    private func createCacheDirectoryIfNeeded() throws {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    private func cachedFileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let fileName = digest.map { String(format: "%02x", $0) }.joined()
        return directoryURL.appendingPathComponent(fileName, isDirectory: false)
    }

    private func trimDiskCacheIfNeeded() {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .fileSizeKey,
            .contentModificationDateKey
        ]

        guard let urls = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return }

        let entries = urls.compactMap { url -> DiskEntry? in
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true
            else { return nil }

            return DiskEntry(
                url: url,
                size: values.fileSize ?? 0,
                lastAccessedAt: values.contentModificationDate ?? .distantPast
            )
        }

        var totalSize = entries.reduce(0) { $0 + $1.size }
        guard totalSize > diskLimitBytes else { return }

        for entry in entries.sorted(by: { $0.lastAccessedAt < $1.lastAccessedAt }) {
            guard totalSize > diskLimitBytes else { break }
            do {
                try fileManager.removeItem(at: entry.url)
                totalSize -= entry.size
            } catch {
                continue
            }
        }
    }
}
