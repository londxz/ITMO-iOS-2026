//
//  AppError.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import Foundation

enum AppError: Error, Equatable, Sendable {
    case networkUnavailable
    case accessDenied
    case notFound
    case requestRejected
    case serverUnavailable
    case invalidData
    case unknown(String)
}

extension AppError {
    init(_ error: any Error) {
        switch NetworkError(error) {
        case .transport:
            self = .networkUnavailable
        case .unauthorized:
            self = .accessDenied
        case .notFound:
            self = .notFound
        case .clientError:
            self = .requestRejected
        case .serverError:
            self = .serverUnavailable
        case .invalidResponse, .unexpectedStatus, .decoding:
            self = .invalidData
        case .invalidURL, .cancelled, .unknown:
            self = .unknown(error.localizedDescription)
        }
    }
}
