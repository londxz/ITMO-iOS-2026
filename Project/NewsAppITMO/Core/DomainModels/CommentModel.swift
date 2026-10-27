//
//  CommentModel.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import Foundation

struct CommentModel: Identifiable, Hashable, Sendable {
    let id: String
    let authorName: String
    let authorAvatarURL: URL?
    let text: String
    let createdAt: Date
    let children: [CommentModel]
}
