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
    let socialImage: String?
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
        case socialImage = "social_image"
        case readingTimeMinutes = "reading_time_minutes"
        case publicReactionsCount = "public_reactions_count"
        case commentsCount = "comments_count"
        case tagList = "tag_list"
        case user, url
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        bodyMarkdown = try container.decodeIfPresent(String.self, forKey: .bodyMarkdown)
        publishedAt = try container.decode(Date.self, forKey: .publishedAt)
        coverImage = try container.decodeIfPresent(String.self, forKey: .coverImage)
        socialImage = try container.decodeIfPresent(String.self, forKey: .socialImage)
        readingTimeMinutes = try container.decode(Int.self, forKey: .readingTimeMinutes)
        publicReactionsCount = try container.decode(Int.self, forKey: .publicReactionsCount)
        commentsCount = try container.decode(Int.self, forKey: .commentsCount)
        // DEV.to's list endpoint uses an array; its detail endpoint uses CSV.
        if let tags = try? container.decode([String].self, forKey: .tagList) {
            tagList = tags
        } else if let tags = try container.decodeIfPresent(String.self, forKey: .tagList) {
            tagList = tags.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty }
        } else {
            tagList = nil
        }
        user = try container.decode(UserDTO.self, forKey: .user)
        url = try container.decodeIfPresent(String.self, forKey: .url)
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
