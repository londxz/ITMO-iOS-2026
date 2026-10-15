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

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            if urlError.code == .cancelled {
                throw NetworkError.cancelled
            }
            throw NetworkError.transport(urlError.code)
        } catch {
            throw NetworkError.unknown
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw NetworkError.unauthorized
        case 500...599:
            throw NetworkError.serverUnavailable(statusCode: httpResponse.statusCode)
        default:
            throw NetworkError.serverUnavailable(statusCode: httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decoding
        }
    }
}
