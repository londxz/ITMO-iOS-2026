//
//  APIConfiguration.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import Foundation

struct APIConfiguration: Sendable {
    let baseURL: URL

    static let devTo = APIConfiguration(
        baseURL: URL(string: "https://dev.to/api")!
    )
}
