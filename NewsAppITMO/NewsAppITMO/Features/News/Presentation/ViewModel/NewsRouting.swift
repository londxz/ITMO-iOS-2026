//
//  NewsRouting.swift
//  NewsAppITMO
//
//  Created by n.a.grebenkin on 08.10.2026.
//

@MainActor
protocol NewsRouting: AnyObject {
    func openPost(id: String)
    func openAuthor(id: String, username: String)
}
