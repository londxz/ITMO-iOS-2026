//
//  BlogState.swift
//  NewsAppITMO
//
//  Created by n.a.grebenkin on 28.10.2026.
//

struct BlogState: Equatable, Sendable {
    var tags: [BlogTagModel] = []
    // nil — фильтр «Все»
    var selectedTag: BlogTagModel?
    var selectedSort: BlogSort = .fresh

    var posts: [PostModel] = []

    var initialLoad: LoadState = .idle
    var paginationLoad: LoadState = .idle

    var currentPage = 1
    var canLoadMore = true

    var isEmpty: Bool {
        posts.isEmpty
    }
}
