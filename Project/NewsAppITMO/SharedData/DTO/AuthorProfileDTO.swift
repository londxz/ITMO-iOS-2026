//
//  AuthorProfileDTO.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import Foundation

struct AuthorProfileDTO: Decodable, Sendable {
    let id: Int
    let username: String
    let name: String
    let summary: String?
    let profileImage: String?
    let location: String?
    let websiteUrl: String?
    let joinedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, username, name, summary, location
        case profileImage = "profile_image"
        case websiteUrl = "website_url"
        case joinedAt = "joined_at"
    }
}
