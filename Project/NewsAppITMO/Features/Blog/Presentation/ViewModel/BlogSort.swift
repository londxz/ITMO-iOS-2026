//
//  BlogSort.swift
//  NewsAppITMO
//
//  Created by n.a.grebenkin on 28.10.2026.
//

enum BlogSort: String, CaseIterable, Hashable, Sendable {
    case fresh
    case topWeek
    case topMonth

    var title: String {
        switch self {
        case .fresh: "Свежие"
        case .topWeek: "Топ недели"
        case .topMonth: "Топ месяца"
        }
    }
}
