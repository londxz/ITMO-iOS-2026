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
    case unauthorized
    case serverUnavailable(statusCode: Int)
    case decoding
    case invalidResponse
    case cancelled
    case unknown
}
