//
//  URLSessionHTTPClient.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import Foundation
import OSLog

final class URLSessionHTTPClient: HTTPClient, Sendable {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    static let acceptEncodingHeader = "Accept-Encoding"
    static let encodingBypassingStaleDevToGzipCache = "identity"

    private let configuration: APIConfiguration
    private let transport: Transport
    private let logger = Logger(subsystem: "NewsAppITMO", category: "HTTPClient")

    convenience init(
        configuration: APIConfiguration = .devTo,
        session: URLSession = .shared
    ) {
        self.init(configuration: configuration) { request in
            try await session.data(for: request)
        }
    }

    init(
        configuration: APIConfiguration = .devTo,
        transport: @escaping Transport
    ) {
        self.configuration = configuration
        self.transport = transport
    }

    @concurrent
    func send<T: Decodable & Sendable>(_ endpoint: any Endpoint) async throws -> T {
        let request = try makeRequest(for: endpoint)
        let path = endpoint.path

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport(request)
        } catch {
            let networkError = Task.isCancelled ? .cancelled : NetworkError(error)
            if networkError != .cancelled {
                let reason = String(describing: error)
                logger.error("\(path, privacy: .public): request failed: \(reason, privacy: .public)")
            }
            throw networkError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("\(path, privacy: .public): response is not HTTP")
            throw NetworkError.invalidResponse
        }

        if let statusError = NetworkError(statusCode: httpResponse.statusCode) {
            logger.error("\(path, privacy: .public): HTTP \(httpResponse.statusCode)")
            throw statusError
        }

        do {
            return try Self.makeDecoder().decode(T.self, from: data)
        } catch {
            let description = String(describing: error)
            logger.error("\(path, privacy: .public): decoding failed: \(description, privacy: .public)")
            throw NetworkError.decoding(description: description)
        }
    }

    private func makeRequest(for endpoint: any Endpoint) throws -> URLRequest {
        var components = URLComponents(
            url: configuration.baseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: true
        )

        if !endpoint.queryItems.isEmpty {
            components?.queryItems = endpoint.queryItems
        }

        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        endpoint.headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue(
            Self.encodingBypassingStaleDevToGzipCache,
            forHTTPHeaderField: Self.acceptEncodingHeader
        )
        return request
    }

    static func makeDecoder() -> JSONDecoder {
        let fractionalSecondsStyle = Date.ISO8601FormatStyle(
            includingFractionalSeconds: true
        )
        let standardStyle = Date.ISO8601FormatStyle()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = try? fractionalSecondsStyle.parse(value) {
                return date
            }

            if let date = try? standardStyle.parse(value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(value)"
            )
        }
        return decoder
    }
}
