//
//  ArticleDTO.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import Foundation

struct ArticleDTO: Decodable, Sendable {
    let id: Int
    let title: String
    let description: String?
    let bodyMarkdown: String?
    let publishedAt: Date
    let coverImage: String?
    let readingTimeMinutes: Int
    let publicReactionsCount: Int
    let commentsCount: Int
    let tagList: [String]?
    let user: UserDTO
    let url: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case bodyMarkdown = "body_markdown"
        case publishedAt = "published_at"
        case coverImage = "cover_image"
        case readingTimeMinutes = "reading_time_minutes"
        case publicReactionsCount = "public_reactions_count"
        case commentsCount = "comments_count"
        case tagList = "tag_list"
        case user, url
    }
}

struct UserDTO: Decodable, Sendable {
    let userId: Int?
    let name: String
    let username: String
    let profileImage: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name, username
        case profileImage = "profile_image"
    }
}
