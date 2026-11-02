//
//  NewsApp.swift
//  NewsApp
//
//  Created by Родион Холодов on 07.10.2026.
//

import SwiftUI

@main
struct NewsApp: App {
    @StateObject private var coordinator = AppCoordinator()
    private let container = AppContainer()
    
    var body: some Scene {
        WindowGroup {
            AppRootTabView(coordinator: coordinator, container: container)
        }
    }
}
