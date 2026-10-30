//
//  AuthorModel.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import Foundation

struct AuthorModel: Identifiable, Hashable, Sendable, Codable {
    let id: String?
    let username: String
    let name: String
    let avatarURL: URL?
    let bio: String?
    let location: String?
    let websiteURL: URL?
    let joinedAt: Date?
}

extension AuthorModel {
    private static let fabricatedLegacyID = "0"

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let storedID = try container.decodeIfPresent(String.self, forKey: .id)
        self.init(
            id: storedID == Self.fabricatedLegacyID ? nil : storedID,
            username: try container.decode(String.self, forKey: .username),
            name: try container.decode(String.self, forKey: .name),
            avatarURL: try container.decodeIfPresent(URL.self, forKey: .avatarURL),
            bio: try container.decodeIfPresent(String.self, forKey: .bio),
            location: try container.decodeIfPresent(String.self, forKey: .location),
            websiteURL: try container.decodeIfPresent(URL.self, forKey: .websiteURL),
            joinedAt: try container.decodeIfPresent(Date.self, forKey: .joinedAt)
        )
    }
}
