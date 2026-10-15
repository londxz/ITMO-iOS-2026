//
//  NewsAction.swift
//  NewsAppITMO
//
//  Created by n.a.grebenkin on 08.10.2026.
//

enum NewsAction: Sendable {
    case onAppear
    case onDisappear
    case refresh
    case loadMore
    case didSelectPost(id: String)
    case didSelectAuthor(id: String, username: String)
}
