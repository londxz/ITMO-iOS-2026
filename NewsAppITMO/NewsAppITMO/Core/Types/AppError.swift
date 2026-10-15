//
//  AppError.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import Foundation

enum AppError: Error, Equatable, Sendable {
    case networkUnavailable
    case serverUnavailable
    case invalidData
    case notFound
    case unknown(String)
}

extension AppError {
    init(_ error: any Error) {
        switch error as? NetworkError {
        case .transport:
            self = .networkUnavailable
        case .serverUnavailable(statusCode: 404):
            self = .notFound
        case .serverUnavailable, .unauthorized:
            self = .serverUnavailable
        case .decoding, .invalidResponse:
            self = .invalidData
        default:
            self = .unknown(error.localizedDescription)
        }
    }
}
