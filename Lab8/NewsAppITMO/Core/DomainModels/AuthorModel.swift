//
//  AuthorModel.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import Foundation

struct AuthorModel: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let username: String
    let name: String
    let avatarURL: URL?
    let bio: String?
    let location: String?
    let websiteURL: URL?
    let joinedAt: Date?
}
