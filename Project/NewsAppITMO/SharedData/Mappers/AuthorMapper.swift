//
//  AuthorMapper.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import Foundation

enum AuthorMapper {
    static func toDomain(_ dto: AuthorProfileDTO) -> AuthorModel {
        AuthorModel(
            id: "\(dto.id)",
            username: dto.username,
            name: dto.name,
            avatarURL: dto.profileImage.flatMap(URL.init(string:)),
            bio: dto.summary,
            location: dto.location,
            websiteURL: dto.websiteUrl.flatMap(URL.init(string:)),
            joinedAt: dto.joinedAt
        )
    }
}
