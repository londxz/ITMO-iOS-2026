//
//  BlogAction.swift
//  NewsAppITMO
//
//  Created by n.a.grebenkin on 28.10.2026.
//

enum BlogAction: Sendable {
    case onAppear
    case onDisappear
    case refresh
    case loadMore
    case selectTag(BlogTagModel?)
    case selectSort(BlogSort)
    case didSelectPost(id: String)
    case didSelectAuthor(id: String, username: String)
}
