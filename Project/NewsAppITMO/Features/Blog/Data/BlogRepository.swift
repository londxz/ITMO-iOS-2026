//
//  BlogRepository.swift
//  NewsAppITMO
//
//  Created by n.a.grebenkin on 28.10.2026.
//

import Foundation

protocol BlogRepository: Sendable {
    func fetchTags() async throws -> [BlogTagModel]

    func fetchArticles(
        tag: String?,
        sort: BlogSort,
        page: Int,
        perPage: Int
    ) async throws -> [PostModel]
}

actor BlogRepositoryImpl: BlogRepository {
    private static let tagsLimit = 10

    private let client: any HTTPClient

    init(client: any HTTPClient) {
        self.client = client
    }

    func fetchTags() async throws -> [BlogTagModel] {
        let dtos: [TagDTO] = try await client.send(BlogEndpoint.tags(perPage: Self.tagsLimit))
        return dtos.map(TagMapper.toDomain)
    }

    func fetchArticles(
        tag: String?,
        sort: BlogSort,
        page: Int,
        perPage: Int
    ) async throws -> [PostModel] {
        let dtos: [ArticleDTO] = try await client.send(
            BlogEndpoint.articles(tag: tag, sort: sort, page: page, perPage: perPage)
        )
        return dtos.map(ArticleMapper.toDomain)
    }
}
