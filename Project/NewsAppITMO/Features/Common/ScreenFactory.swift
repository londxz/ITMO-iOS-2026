//
//  ScreenFactory.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import SwiftUI

@MainActor
protocol ScreenFactory {
    func makePostDetailView(id: String) -> AnyView
    func makeAuthorProfileView(id: String, username: String) -> AnyView
    func makeCommentsSheet(postID: String) -> AnyView
}
