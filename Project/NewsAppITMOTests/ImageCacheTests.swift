import UIKit
import XCTest
@testable import NewsAppITMO

private let url = URL(string: "https://example.com/cover.png")!
private let otherURL = URL(string: "https://example.com/avatar.png")!
private let samplePNG: Data = {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2))
    return renderer.pngData { context in
        UIColor.systemTeal.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
    }
}()

final class ImageCacheTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImageCacheTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    func testConcurrentRequestsForSameURLShareOneDownload() async throws {
        let probe = LoaderProbe()
        await probe.hold(url)
        let cache = makeCache(probe)

        let first = Task { try await cache.data(for: url) }
        try await waitUntil { await probe.callCount == 1 }
        let second = Task { try await cache.data(for: url) }
        try await waitUntil { await cache.waitingConsumerCount(for: url) == 2 }

        await probe.release(url)
        let firstData = try await first.value
        let secondData = try await second.value

        XCTAssertEqual(firstData, samplePNG)
        XCTAssertEqual(secondData, samplePNG)
        let callCount = await probe.callCount
        XCTAssertEqual(callCount, 1)
        let waiting = await cache.waitingConsumerCount(for: url)
        XCTAssertEqual(waiting, 0)
    }

    func testCancellingOneConsumerKeepsDownloadForAnother() async throws {
        let probe = LoaderProbe()
        await probe.hold(url)
        let cache = makeCache(probe)

        let cancelled = Task { try await cache.data(for: url) }
        try await waitUntil { await probe.callCount == 1 }
        let remaining = Task { try await cache.data(for: url) }
        try await waitUntil { await cache.waitingConsumerCount(for: url) == 2 }

        cancelled.cancel()
        try await waitUntil { await cache.waitingConsumerCount(for: url) == 1 }
        let cancellationsBeforeRelease = await probe.cancellationCount
        XCTAssertEqual(cancellationsBeforeRelease, 0)

        await probe.release(url)
        let remainingData = try await remaining.value
        XCTAssertEqual(remainingData, samplePNG)
        await assertCancelled(cancelled)
        let callCount = await probe.callCount
        XCTAssertEqual(callCount, 1)
    }

    func testCancellingLastConsumerCancelsDownload() async throws {
        let probe = LoaderProbe()
        await probe.hold(url)
        let cache = makeCache(probe)

        let consumer = Task { try await cache.data(for: url) }
        try await waitUntil { await probe.callCount == 1 }
        consumer.cancel()

        try await waitUntil { await probe.cancellationCount == 1 }
        await assertCancelled(consumer)
        let waiting = await cache.waitingConsumerCount(for: url)
        XCTAssertEqual(waiting, 0)
        XCTAssertFalse(fileExists(for: url))

        await probe.allow(url)
        let retried = try await cache.data(for: url)
        XCTAssertEqual(retried, samplePNG)
        let callCount = await probe.callCount
        XCTAssertEqual(callCount, 2)
    }

    func testSuccessfulDownloadIsStoredInMemoryAndOnDisk() async throws {
        let probe = LoaderProbe()
        let cache = makeCache(probe)

        _ = try await cache.data(for: url)
        XCTAssertTrue(fileExists(for: url))

        let diskOnlyProbe = LoaderProbe()
        let fromDisk = try await makeCache(diskOnlyProbe).data(for: url)
        XCTAssertEqual(fromDisk, samplePNG)
        let diskOnlyCalls = await diskOnlyProbe.callCount
        XCTAssertEqual(diskOnlyCalls, 0)

        try FileManager.default.removeItem(at: cacheFile(for: url))
        let fromMemory = try await cache.data(for: url)
        XCTAssertEqual(fromMemory, samplePNG)
        let callCount = await probe.callCount
        XCTAssertEqual(callCount, 1)
    }

    func testCorruptedDiskFileIsRemovedAndDownloadedAgain() async throws {
        let probe = LoaderProbe()
        _ = try await makeCache(probe).data(for: url)
        try Data("not an image".utf8).write(to: cacheFile(for: url))

        let restartedCache = makeCache(probe)
        let data = try await restartedCache.data(for: url)

        XCTAssertEqual(data, samplePNG)
        let callCount = await probe.callCount
        XCTAssertEqual(callCount, 2)
        XCTAssertEqual(try Data(contentsOf: cacheFile(for: url)), samplePNG)
    }

    func testResponseThatIsNotAnImageIsRejectedAndNotCached() async throws {
        let probe = LoaderProbe()
        await probe.respond(with: Data("<html>error</html>".utf8), statusCode: 200)
        let cache = makeCache(probe)

        do {
            _ = try await cache.data(for: url)
            XCTFail("Expected invalid response")
        } catch {
            XCTAssertEqual(error as? NetworkError, .invalidResponse)
        }
        XCTAssertFalse(fileExists(for: url))

        await probe.respond(with: Data(), statusCode: 200)
        do {
            _ = try await cache.data(for: url)
            XCTFail("Expected invalid response")
        } catch {
            XCTAssertEqual(error as? NetworkError, .invalidResponse)
        }
    }

    func testClearCacheRemovesMemoryDiskAndActiveRequests() async throws {
        let probe = LoaderProbe()
        let cache = makeCache(probe)
        _ = try await cache.data(for: url)
        await probe.hold(otherURL)
        let active = Task { try await cache.data(for: otherURL) }
        try await waitUntil { await probe.callCount == 2 }

        try await cache.clearCache()

        await assertCancelled(active)
        try await waitUntil { await probe.cancellationCount == 1 }
        XCTAssertFalse(fileExists(for: url))
        XCTAssertFalse(fileExists(for: otherURL))
        let waiting = await cache.waitingConsumerCount(for: otherURL)
        XCTAssertEqual(waiting, 0)

        _ = try await cache.data(for: url)
        let callCount = await probe.callCount
        XCTAssertEqual(callCount, 3)
    }

    func testExceedingDiskLimitRemovesOlderFilesFirst() async throws {
        let probe = LoaderProbe()
        let size = samplePNG.count
        let cache = makeCache(probe, diskLimitBytes: Int(Double(size) * 2.8))
        let oldest = URL(string: "https://example.com/oldest.png")!
        let older = URL(string: "https://example.com/older.png")!
        let newest = URL(string: "https://example.com/newest.png")!

        _ = try await cache.data(for: oldest)
        _ = try await cache.data(for: older)
        try setModificationDate(Date(timeIntervalSince1970: 1_600_000_000), for: oldest)
        try setModificationDate(Date(timeIntervalSince1970: 1_650_000_000), for: older)

        _ = try await cache.data(for: newest)

        XCTAssertFalse(fileExists(for: oldest))
        XCTAssertTrue(fileExists(for: older))
        XCTAssertTrue(fileExists(for: newest))
    }

    func testImageValidationAcceptsImagesAndRejectsBrokenData() {
        XCTAssertTrue(ImageCacheImpl.isDecodableImage(samplePNG))
        XCTAssertFalse(ImageCacheImpl.isDecodableImage(Data()))
        XCTAssertFalse(ImageCacheImpl.isDecodableImage(Data("<html>error</html>".utf8)))
        XCTAssertFalse(ImageCacheImpl.isDecodableImage(samplePNG.prefix(16)))
        XCTAssertFalse(ImageCacheImpl.isDecodableImage(samplePNG.prefix(8) + Data(repeating: 0x41, count: 200)))
    }

    private func makeCache(_ probe: LoaderProbe, diskLimitBytes: Int = 10 * 1024 * 1024) -> ImageCacheImpl {
        ImageCacheImpl(
            loader: { url in try await probe.load(url) },
            directoryURL: directory,
            diskLimitBytes: diskLimitBytes
        )
    }

    private func cacheFile(for url: URL) -> URL {
        directory.appendingPathComponent(ImageCacheImpl.cacheFileName(for: url))
    }

    private func fileExists(for url: URL) -> Bool {
        FileManager.default.fileExists(atPath: cacheFile(for: url).path)
    }

    private func setModificationDate(_ date: Date, for url: URL) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: cacheFile(for: url).path)
    }

    private func assertCancelled(
        _ task: Task<Data, any Error>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await task.value
            XCTFail("Expected cancellation", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? NetworkError, .cancelled, file: file, line: line)
        }
    }

    private func waitUntil(
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @Sendable () async -> Bool
    ) async throws {
        for _ in 0..<400 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Condition was not met in time", file: file, line: line)
    }
}

private actor LoaderProbe {
    private(set) var callCount = 0
    private(set) var cancellationCount = 0
    private var heldURLs: Set<URL> = []
    private var pending: [URL: CheckedContinuation<Void, any Error>] = [:]
    private var body = samplePNG
    private var statusCode = 200

    func hold(_ url: URL) {
        heldURLs.insert(url)
    }

    func allow(_ url: URL) {
        heldURLs.remove(url)
    }

    func release(_ url: URL) {
        heldURLs.remove(url)
        pending.removeValue(forKey: url)?.resume()
    }

    func respond(with data: Data, statusCode: Int) {
        body = data
        self.statusCode = statusCode
    }

    func load(_ url: URL) async throws -> (Data, URLResponse) {
        callCount += 1
        if heldURLs.contains(url) {
            try await withTaskCancellationHandler {
                try await suspend(url)
            } onCancel: {
                Task { await self.cancel(url) }
            }
        }
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return (body, response)
    }

    private func suspend(_ url: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            if Task.isCancelled {
                continuation.resume(throwing: CancellationError())
            } else {
                pending[url] = continuation
            }
        }
    }

    private func cancel(_ url: URL) {
        cancellationCount += 1
        pending.removeValue(forKey: url)?.resume(throwing: CancellationError())
    }
}
