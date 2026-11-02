//
//  CommentMapper.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import Foundation

enum CommentMapper {
    static func toDomain(_ dto: CommentDTO) -> CommentModel {
        let cleanText = dto.bodyHtml
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return CommentModel(
            id: dto.idCode,
            authorName: dto.user.name,
            authorAvatarURL: dto.user.profileImage90.flatMap(URL.init(string:)),
            text: cleanText,
            createdAt: dto.createdAt,
            children: dto.children.map { toDomain($0) }
        )
    }
}
