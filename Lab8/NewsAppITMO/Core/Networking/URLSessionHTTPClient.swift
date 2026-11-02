//
//  URLSessionHTTPClient.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import Foundation

final class URLSessionHTTPClient: HTTPClient, Sendable {
    private let configuration: APIConfiguration
    private let session: URLSession

    init(
        configuration: APIConfiguration = .devTo,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
    }

    @concurrent
    func send<T: Decodable & Sendable>(_ endpoint: any Endpoint) async throws -> T {
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
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw NetworkError.cancelled
        } catch let urlError as URLError {
            if urlError.code == .cancelled {
                throw NetworkError.cancelled
            }
            throw NetworkError.transport(urlError.code)
        } catch {
            if Task.isCancelled {
                throw NetworkError.cancelled
            }
            throw NetworkError.unknown
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401, 403:
            throw NetworkError.unauthorized
        case 404:
            throw NetworkError.serverUnavailable(statusCode: httpResponse.statusCode)
        case 500...599:
            throw NetworkError.serverUnavailable(statusCode: httpResponse.statusCode)
        default:
            throw NetworkError.serverUnavailable(statusCode: httpResponse.statusCode)
        }

        do {
            let decoder = Self.makeDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decoding
        }
    }

    private static func makeDecoder() -> JSONDecoder {
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
