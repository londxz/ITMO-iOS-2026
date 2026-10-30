//
//  ImageCache.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 27.10.2026.
//

import CryptoKit
import Foundation
import ImageIO

protocol ImageCache: Sendable {
    func data(for url: URL) async throws -> Data
    func clearCache() async throws
}

actor ImageCacheImpl: ImageCache {
    typealias Loader = @Sendable (URL) async throws -> (Data, URLResponse)

    private static let defaultDiskLimitBytes = 150 * 1024 * 1024
    private static let defaultMemoryLimitBytes = 50 * 1024 * 1024
    private static let trimTargetRatio = 0.8

    private struct InFlightRequest {
        let id: UUID
        let task: Task<Data, any Error>
        var waiters: Set<UUID>
    }

    private struct DiskEntry {
        let url: URL
        let size: Int
        let lastAccessedAt: Date
    }

    private let loader: Loader
    private let fileManager: FileManager
    private let directoryURL: URL
    private let diskLimitBytes: Int
    private let memoryCache = NSCache<NSURL, NSData>()

    private var inFlightRequests: [URL: InFlightRequest] = [:]
    private var diskUsageBytes: Int?

    init(
        loader: @escaping Loader = { try await URLSession.shared.data(from: $0) },
        fileManager: FileManager = .default,
        directoryURL: URL? = nil,
        diskLimitBytes: Int = ImageCacheImpl.defaultDiskLimitBytes,
        memoryLimitBytes: Int = ImageCacheImpl.defaultMemoryLimitBytes
    ) {
        self.loader = loader
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
        let request = joinOrCreateRequest(for: url, waiterID: waiterID)

        do {
            let data = try await withTaskCancellationHandler {
                try await request.task.value
            } onCancel: {
                Task {
                    await self.releaseWaiter(waiterID, of: request.id, for: url)
                }
            }
            try Task.checkCancellation()
            return data
        } catch {
            releaseWaiter(waiterID, of: request.id, for: url)
            throw NetworkError(error)
        }
    }

    func clearCache() throws {
        let activeRequests = inFlightRequests.values
        inFlightRequests.removeAll()
        activeRequests.forEach { $0.task.cancel() }
        memoryCache.removeAllObjects()

        diskUsageBytes = nil
        if fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.removeItem(at: directoryURL)
        }
        try createCacheDirectoryIfNeeded()
        diskUsageBytes = 0
    }

    func waitingConsumerCount(for url: URL) -> Int {
        inFlightRequests[url]?.waiters.count ?? 0
    }

    static func cacheFileName(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func isDecodableImage(_ data: Data) -> Bool {
        guard !data.isEmpty,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0
        else { return false }
        return CGImageSourceCreateImageAtIndex(source, 0, nil) != nil
    }

    private func joinOrCreateRequest(for url: URL, waiterID: UUID) -> InFlightRequest {
        if var request = inFlightRequests[url] {
            request.waiters.insert(waiterID)
            inFlightRequests[url] = request
            return request
        }

        let requestID = UUID()
        let loader = loader
        let task = Task<Data, any Error> {
            let result: Result<Data, any Error>
            do {
                result = .success(try await Self.download(url, using: loader))
            } catch {
                result = .failure(error)
            }
            return try self.finishRequest(requestID, for: url, with: result)
        }

        let request = InFlightRequest(id: requestID, task: task, waiters: [waiterID])
        inFlightRequests[url] = request
        return request
    }

    private func finishRequest(
        _ requestID: UUID,
        for url: URL,
        with result: Result<Data, any Error>
    ) throws -> Data {
        let isActive = inFlightRequests[url]?.id == requestID
        if isActive {
            inFlightRequests[url] = nil
        }

        let data = try result.get()
        if isActive {
            storeInMemory(data, for: url)
            storeOnDisk(data, for: url)
        }
        return data
    }

    private func releaseWaiter(_ waiterID: UUID, of requestID: UUID, for url: URL) {
        guard var request = inFlightRequests[url],
              request.id == requestID,
              request.waiters.remove(waiterID) != nil
        else { return }

        if request.waiters.isEmpty {
            inFlightRequests[url] = nil
            request.task.cancel()
        } else {
            inFlightRequests[url] = request
        }
    }

    @concurrent
    private static func download(_ url: URL, using loader: Loader) async throws -> Data {
        let (data, response) = try await loader(url)
        try Task.checkCancellation()

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        if let statusError = NetworkError(statusCode: httpResponse.statusCode) {
            throw statusError
        }
        guard isDecodableImage(data) else {
            throw NetworkError.invalidResponse
        }
        return data
    }

    private func storeInMemory(_ data: Data, for url: URL) {
        memoryCache.setObject(
            data as NSData,
            forKey: url as NSURL,
            cost: data.count
        )
    }
}

extension ImageCacheImpl {
    private func loadFromDisk(for url: URL) -> Data? {
        let fileURL = cachedFileURL(for: url)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }

        guard let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe),
              Self.isDecodableImage(data)
        else {
            removeDiskFile(at: fileURL)
            return nil
        }

        try? fileManager.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: fileURL.path
        )
        return data
    }

    private func storeOnDisk(_ data: Data, for url: URL) {
        let fileURL = cachedFileURL(for: url)
        let previousSize = fileSize(at: fileURL)
        do {
            try createCacheDirectoryIfNeeded()
            try data.write(to: fileURL, options: .atomic)
        } catch {
            return
        }

        if let usage = diskUsageBytes {
            diskUsageBytes = usage - previousSize + data.count
        } else {
            diskUsageBytes = diskEntries().reduce(0) { $0 + $1.size }
        }

        if let usage = diskUsageBytes, usage > diskLimitBytes {
            trimDiskCache()
        }
    }

    private func removeDiskFile(at fileURL: URL) {
        let size = fileSize(at: fileURL)
        guard (try? fileManager.removeItem(at: fileURL)) != nil else { return }
        if let usage = diskUsageBytes {
            diskUsageBytes = max(0, usage - size)
        }
    }

    private func createCacheDirectoryIfNeeded() throws {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    private func cachedFileURL(for url: URL) -> URL {
        directoryURL.appendingPathComponent(Self.cacheFileName(for: url), isDirectory: false)
    }

    private func fileSize(at fileURL: URL) -> Int {
        let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path)
        return (attributes?[.size] as? NSNumber)?.intValue ?? 0
    }

    private func diskEntries() -> [DiskEntry] {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .fileSizeKey,
            .contentModificationDateKey
        ]

        guard let urls = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return urls.compactMap { url -> DiskEntry? in
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  let size = values.fileSize
            else { return nil }

            return DiskEntry(
                url: url,
                size: size,
                lastAccessedAt: values.contentModificationDate ?? .distantPast
            )
        }
    }

    private func trimDiskCache() {
        let entries = diskEntries()
        let targetBytes = Int(Double(diskLimitBytes) * Self.trimTargetRatio)
        var totalSize = entries.reduce(0) { $0 + $1.size }

        for entry in entries.sorted(by: { $0.lastAccessedAt < $1.lastAccessedAt }) {
            guard totalSize > targetBytes else { break }
            if (try? fileManager.removeItem(at: entry.url)) != nil {
                totalSize -= entry.size
            }
        }
        diskUsageBytes = totalSize
    }
}
