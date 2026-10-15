//
//  NewsState.swift
//  NewsAppITMO
//
//  Created by n.a.grebenkin on 08.10.2026.
//

struct NewsState: Equatable, Sendable {
    var heroPost: PostModel?
    var posts: [PostModel] = []
    var initialLoad: LoadState = .idle
    var paginationLoad: LoadState = .idle
    var currentPage: Int = 1
    var canLoadMore: Bool = true

    var isEmpty: Bool {
        heroPost == nil && posts.isEmpty
    }
}
