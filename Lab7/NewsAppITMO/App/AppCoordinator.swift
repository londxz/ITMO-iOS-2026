//
//  AppCoordinator.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import SwiftUI
import Combine

enum AppTab: Hashable, Sendable {
    case news
    case blog
    case bookmarks
    case settings
}

@MainActor
final class AppCoordinator: ObservableObject {
   @Published var selectedTab: AppTab = .news
    
    let newsCoordinator = NewsCoordinator()
}
