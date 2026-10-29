import XCTest
@testable import NewsAppITMO

final class HTTPClientTests: XCTestCase {
    func testBuildsURLFromBasePathAndQueryItems() async throws {
        let transport = TransportStub(.http(200, #"{"value":"ok"}"#))
        let client = makeClient(transport)
        let endpoint = TestEndpoint(
            path: "articles",
            queryItems: [URLQueryItem(name: "tag", value: "swift"), URLQueryItem(name: "page", value: "2")]
        )

        let _: Payload = try await client.send(endpoint)

        let requests = await transport.requests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://dev.to/api/articles?tag=swift&page=2")
        XCTAssertEqual(request.httpMethod, "GET")
    }

    func testAppliesEndpointHeadersAndMethod() async throws {
        let transport = TransportStub(.http(200, #"{"value":"ok"}"#))
        let endpoint = TestEndpoint(path: "comments", method: .post, headers: ["X-Test": "1"])

        let _: Payload = try await makeClient(transport).send(endpoint)

        let requests = await transport.requests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Test"), "1")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertNil(request.url?.query)
    }

    func testRequestsIdentityEncodingToBypassStaleDevToGzipCache() async throws {
        let transport = TransportStub(.http(200, #"{"value":"ok"}"#))
        let endpoint = TestEndpoint(path: "articles", headers: ["Accept-Encoding": "gzip"])

        let _: Payload = try await makeClient(transport).send(endpoint)

        let requests = await transport.requests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept-Encoding"), "identity")
    }

    func testDecodesSuccessfulResponse() async throws {
        for status in [200, 201, 299] {
            let payload: Payload = try await makeClient(TransportStub(.http(status, #"{"value":"ok"}"#)))
                .send(TestEndpoint())
            XCTAssertEqual(payload.value, "ok")
        }
    }

    func testClassifiesHTTPFailures() async {
        let expectations = [
            StatusExpectation(status: 401, networkError: .unauthorized(statusCode: 401), appError: .accessDenied),
            StatusExpectation(status: 403, networkError: .unauthorized(statusCode: 403), appError: .accessDenied),
            StatusExpectation(status: 404, networkError: .notFound, appError: .notFound),
            StatusExpectation(status: 422, networkError: .clientError(statusCode: 422), appError: .requestRejected),
            StatusExpectation(status: 429, networkError: .clientError(statusCode: 429), appError: .requestRejected),
            StatusExpectation(status: 500, networkError: .serverError(statusCode: 500), appError: .serverUnavailable),
            StatusExpectation(status: 503, networkError: .serverError(statusCode: 503), appError: .serverUnavailable),
            StatusExpectation(status: 304, networkError: .unexpectedStatus(statusCode: 304), appError: .invalidData)
        ]

        for expectation in expectations {
            let error = await sendExpectingError(TransportStub(.http(expectation.status, "{}")))
            XCTAssertEqual(error, expectation.networkError, "status \(expectation.status)")
            XCTAssertEqual(AppError(expectation.networkError), expectation.appError, "status \(expectation.status)")
        }
    }

    func testURLCancellationBecomesCancellationInsteadOfFailure() async {
        let error = await sendExpectingError(TransportStub(.failure(URLError(.cancelled))))
        XCTAssertEqual(error, .cancelled)
        XCTAssertTrue(NetworkError.isCancellation(error))
    }

    func testTransportErrorsKeepTheirReason() async {
        let offline = await sendExpectingError(TransportStub(.failure(URLError(.notConnectedToInternet))))
        let timeout = await sendExpectingError(TransportStub(.failure(URLError(.timedOut))))
        XCTAssertEqual(offline, .transport(.notConnectedToInternet))
        XCTAssertEqual(timeout, .transport(.timedOut))
        XCTAssertEqual(AppError(offline), .networkUnavailable)
        XCTAssertEqual(AppError(timeout), .networkUnavailable)
    }

    func testNonHTTPResponseIsReportedAsInvalidResponse() async {
        let error = await sendExpectingError(TransportStub(.nonHTTP))
        XCTAssertEqual(error, .invalidResponse)
        XCTAssertEqual(AppError(error), .invalidData)
    }

    func testDecodingFailureKeepsDiagnosticDescription() async {
        let error = await sendExpectingError(TransportStub(.http(200, #"{"other":"field"}"#)))
        guard case .decoding(let description) = error else {
            return XCTFail("Expected decoding error, got \(error)")
        }
        XCTAssertTrue(description.contains("value"), description)
        XCTAssertEqual(AppError(error), .invalidData)
    }

    func testDecodesISO8601DatesWithAndWithoutFractionalSeconds() async throws {
        let json = #"{"plain":"2026-10-01T12:00:00Z","fractional":"2026-10-01T12:00:00.250Z"}"#
        let dates: DatesPayload = try await makeClient(TransportStub(.http(200, json))).send(TestEndpoint())

        XCTAssertEqual(dates.plain.timeIntervalSince1970, 1_790_856_000, accuracy: 0.001)
        XCTAssertEqual(dates.fractional.timeIntervalSince1970, 1_790_856_000.25, accuracy: 0.001)
    }

    func testInvalidDateIsReportedAsDecodingError() async {
        let json = #"{"plain":"yesterday","fractional":"2026-10-01T12:00:00.250Z"}"#
        let client = makeClient(TransportStub(.http(200, json)))
        do {
            let _: DatesPayload = try await client.send(TestEndpoint())
            XCTFail("Expected decoding error")
        } catch {
            guard case .decoding(let description) = error as? NetworkError else {
                return XCTFail("Expected decoding error, got \(error)")
            }
            XCTAssertTrue(description.contains("yesterday"), description)
        }
    }

    func testUnknownErrorsKeepDescriptionForLogs() {
        let error = NetworkError(CocoaError(.fileReadCorruptFile))
        guard case .unknown(let description) = error else {
            return XCTFail("Expected unknown error, got \(error)")
        }
        XCTAssertFalse(description.isEmpty)
        XCTAssertFalse(NetworkError.isCancellation(CocoaError(.fileReadCorruptFile)))
        XCTAssertTrue(NetworkError.isCancellation(CancellationError()))
    }

    private func makeClient(_ transport: TransportStub) -> URLSessionHTTPClient {
        URLSessionHTTPClient { request in
            try await transport.respond(to: request)
        }
    }

    private func sendExpectingError(
        _ transport: TransportStub,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> NetworkError {
        do {
            let _: Payload = try await makeClient(transport).send(TestEndpoint())
            XCTFail("Expected an error", file: file, line: line)
            return .unknown(description: "no error")
        } catch let error as NetworkError {
            return error
        } catch {
            XCTFail("Unexpected error type: \(error)", file: file, line: line)
            return .unknown(description: String(describing: error))
        }
    }
}

private struct StatusExpectation {
    let status: Int
    let networkError: NetworkError
    let appError: AppError
}

private struct Payload: Decodable, Sendable {
    let value: String
}

private struct DatesPayload: Decodable, Sendable {
    let plain: Date
    let fractional: Date
}

private struct TestEndpoint: Endpoint {
    var path = "articles"
    var method: HTTPMethod = .get
    var headers: [String: String] = [:]
    var queryItems: [URLQueryItem] = []
}

private actor TransportStub {
    enum Reply: Sendable {
        case http(Int, String)
        case nonHTTP
        case failure(URLError)
    }

    private let reply: Reply
    private(set) var requests: [URLRequest] = []

    init(_ reply: Reply) {
        self.reply = reply
    }

    func respond(to request: URLRequest) throws -> (Data, URLResponse) {
        requests.append(request)
        let url = request.url ?? URL(string: "https://dev.to")!
        switch reply {
        case .http(let status, let body):
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (Data(body.utf8), response)
        case .nonHTTP:
            let response = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
            return (Data(), response)
        case .failure(let error):
            throw error
        }
    }
}
