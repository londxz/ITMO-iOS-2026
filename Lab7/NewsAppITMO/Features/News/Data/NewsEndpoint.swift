//
//  NewsEndpoint.swift
//  NewsAppITMO
//
//  Created by n.a.grebenkin on 08.10.2026.
//

import Foundation

enum NewsEndpoint: Endpoint {
    case dayTop
    case fresh(page: Int, perPage: Int)

    var path: String {
        APIPath.articles
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .dayTop:
            [
                URLQueryItem(name: "tag", value: "news"),
                URLQueryItem(name: "top", value: "1"),
                URLQueryItem(name: "per_page", value: "1")
            ]
        case .fresh(let page, let perPage):
            [
                URLQueryItem(name: "tag", value: "news"),
                URLQueryItem(name: "state", value: "fresh"),
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "per_page", value: "\(perPage)")
            ]
        }
    }
}
