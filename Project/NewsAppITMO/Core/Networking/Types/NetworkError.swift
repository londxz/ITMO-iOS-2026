//
//  NetworkError.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import Foundation

enum NetworkError: Error, Equatable, Sendable {
    case invalidURL
    case transport(URLError.Code)
    case cancelled
    case unauthorized(statusCode: Int)
    case notFound
    case clientError(statusCode: Int)
    case serverError(statusCode: Int)
    case unexpectedStatus(statusCode: Int)
    case invalidResponse
    case decoding(description: String)
    case unknown(description: String)
}

extension NetworkError {
    init?(statusCode: Int) {
        switch statusCode {
        case 200...299:
            return nil
        case 401, 403:
            self = .unauthorized(statusCode: statusCode)
        case 404:
            self = .notFound
        case 400...499:
            self = .clientError(statusCode: statusCode)
        case 500...599:
            self = .serverError(statusCode: statusCode)
        default:
            self = .unexpectedStatus(statusCode: statusCode)
        }
    }

    init(_ error: any Error) {
        switch error {
        case let networkError as NetworkError:
            self = networkError
        case is CancellationError:
            self = .cancelled
        case let urlError as URLError:
            self = urlError.code == .cancelled ? .cancelled : .transport(urlError.code)
        default:
            self = .unknown(description: String(describing: error))
        }
    }

    static func isCancellation(_ error: any Error) -> Bool {
        NetworkError(error) == .cancelled
    }
}
