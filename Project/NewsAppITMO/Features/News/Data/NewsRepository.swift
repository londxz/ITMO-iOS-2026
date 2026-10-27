//
//  NewsRepository.swift
//  NewsAppITMO
//
//  Created by n.a.grebenkin on 08.10.2026.
//

import Foundation
import OSLog

protocol NewsRepository: Sendable {
    func fetchDayTopPost() async throws -> PostModel?
    func fetchFreshPosts(page: Int, perPage: Int) async throws -> [PostModel]
}

actor NewsRepositoryImpl: NewsRepository {
    private let client: any HTTPClient
    private let logger = Logger(subsystem: "NewsAppITMO", category: "NewsRepository")

    init(client: any HTTPClient) {
        self.client = client
    }

    func fetchDayTopPost() async throws -> PostModel? {
        logger.debug("dayTop request started, isMainThread: \(Thread.isMainThread)")
        let dtos: [ArticleDTO] = try await client.send(NewsEndpoint.dayTop)
        logger.debug("dayTop request finished")
        return dtos.first.map(ArticleMapper.toDomain)
    }

    func fetchFreshPosts(page: Int, perPage: Int) async throws -> [PostModel] {
        logger.debug("fresh page \(page) request started, isMainThread: \(Thread.isMainThread)")
        let dtos: [ArticleDTO] = try await client.send(NewsEndpoint.fresh(page: page, perPage: perPage))
        logger.debug("fresh page \(page) request finished, count: \(dtos.count)")
        return dtos.map(ArticleMapper.toDomain)
    }
}
