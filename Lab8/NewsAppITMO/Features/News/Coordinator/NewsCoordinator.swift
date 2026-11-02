//
//  NewsCoordinator.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import SwiftUI
import Combine

@MainActor
final class NewsCoordinator: ObservableObject, NewsRouting {
    @Published var path = NavigationPath()

    func openPost(id: String) {
        path.append(NewsFlowRoute.postDetail(id: id))
    }

    func openAuthor(id: String, username: String) {
        path.append(NewsFlowRoute.authorProfile(id: id, username: username))
    }
}
