//
//  BlogRouting.swift
//  NewsAppITMO
//
//  Created by n.a.grebenkin on 28.10.2026.
//

@MainActor
protocol BlogRouting: AnyObject {
    func openPost(id: String)
    func openAuthor(id: String, username: String)
}
