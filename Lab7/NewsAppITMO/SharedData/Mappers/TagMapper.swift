//
//  TagMapper.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import Foundation

enum TagMapper {
    static func toDomain(_ dto: TagDTO) -> BlogTagModel {
        BlogTagModel(
            id: "\(dto.id)",
            name: dto.name
        )
    }
}
