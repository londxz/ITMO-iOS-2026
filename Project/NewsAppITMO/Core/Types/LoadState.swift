//
//  LoadState.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

enum LoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed(AppError)
}
