//
//  CommentUserDTO.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import Foundation

struct CommentUserDTO: Decodable, Sendable {
    let name: String
    let profileImage90: String?

    enum CodingKeys: String, CodingKey {
        case name
        case profileImage90 = "profile_image_90"
    }
}

struct CommentDTO: Decodable, Sendable {
    let idCode: String
    let createdAt: Date
    let bodyHtml: String
    let user: CommentUserDTO
    let children: [CommentDTO]

    enum CodingKeys: String, CodingKey {
        case idCode = "id_code"
        case createdAt = "created_at"
        case bodyHtml = "body_html"
        case user, children
    }
}
