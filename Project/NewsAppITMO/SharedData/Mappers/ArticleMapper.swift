//
//  ArticleMapper.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import Foundation

enum ArticleMapper {
    static func toDomain(_ dto: ArticleDTO) -> PostModel {
        let imageURL = dto.coverImage ?? dto.socialImage
        let author = AuthorModel(
            id: dto.user.userId.map { String($0) },
            username: dto.user.username,
            name: dto.user.name,
            avatarURL: dto.user.profileImage.flatMap(URL.init(string:)),
            bio: nil,
            location: nil,
            websiteURL: nil,
            joinedAt: nil
        )

        return PostModel(
            id: "\(dto.id)",
            title: dto.title,
            summary: dto.description ?? "",
            bodyMarkdown: dto.bodyMarkdown,
            publishedAt: dto.publishedAt,
            coverImageURL: imageURL.flatMap(URL.init(string:)),
            readingTimeMinutes: dto.readingTimeMinutes,
            reactionsCount: dto.publicReactionsCount,
            commentsCount: dto.commentsCount,
            tags: dto.tagList ?? [],
            author: author,
            webURL: dto.url.flatMap(URL.init(string:))
        )
    }
}
