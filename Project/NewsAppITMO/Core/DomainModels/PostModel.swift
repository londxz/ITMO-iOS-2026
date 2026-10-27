//
//  PostModel.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import Foundation

struct PostModel: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let title: String
    let summary: String
    let bodyMarkdown: String?
    let publishedAt: Date
    let coverImageURL: URL?
    let readingTimeMinutes: Int
    let reactionsCount: Int
    let commentsCount: Int
    let tags: [String]
    let author: AuthorModel
    let webURL: URL?
}
