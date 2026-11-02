//
//  NewsFlowRoute.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

enum NewsFlowRoute: Hashable, Sendable {
    case postDetail(id: String)
    case authorProfile(id: String, username: String)
}
