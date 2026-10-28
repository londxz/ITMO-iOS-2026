//
//  BlogFlowRoute.swift
//  NewsAppITMO
//
//  Created by n.a.grebenkin on 28.10.2026.
//

enum BlogFlowRoute: Hashable, Sendable {
    case postDetail(id: String)
    case authorProfile(id: String, username: String)
}
