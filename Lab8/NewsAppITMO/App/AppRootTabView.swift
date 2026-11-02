//
//  AppRootTabView.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import SwiftUI

struct AppRootTabView: View {
    @ObservedObject var coordinator: AppCoordinator
    @AppStorage(SettingsStorageKey.appTheme) private var appTheme: AppTheme = .system
    let container: AppContainer
    private let screenFactory: ScreenFactory
    private let newsRepository: any NewsRepository
    private let blogRepository: any BlogRepository
    
    init(coordinator: AppCoordinator, container: AppContainer) {
        self.coordinator = coordinator
        self.container = container
        self.screenFactory = AppScreenFactory(container: container)
        self.newsRepository = NewsRepositoryImpl(client: container.httpClient)
        self.blogRepository = BlogRepositoryImpl(client: container.httpClient)
    }
    
    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            
            // Новости
            NewsCoordinatorView(
                coordinator: coordinator.newsCoordinator,
                screenFactory: screenFactory,
                repository: newsRepository,
                imageCache: container.imageCache
            )
            .tabItem {
                Label("Новости", systemImage: "newspaper")
            }
            .tag(AppTab.news)
            
            // Блог
            BlogCoordinatorView(
                coordinator: coordinator.blogCoordinator,
                screenFactory: screenFactory,
                repository: blogRepository,
                imageCache: container.imageCache
            )
            .tabItem {
                Label("Блог", systemImage: "doc.text.image")
            }
            .tag(AppTab.blog)
            
            // Закладки
            BookmarksCoordinatorView(
                coordinator: coordinator.bookmarksCoordinator,
                storage: container.bookmarksStorage,
                imageCache: container.imageCache,
                screenFactory: screenFactory
            )
            .tabItem {
                Label("Закладки", systemImage: "bookmark")
            }
            .tag(AppTab.bookmarks)
            
            // Настройки
            NavigationStack {
                SettingsView(
                    viewModel: SettingsViewModel(imageCache: container.imageCache)
                )
            }
            .tabItem {
                Label("Настройки", systemImage: "gearshape")
            }
            .tag(AppTab.settings)
        }
        .preferredColorScheme(appTheme.colorScheme)
    }
}
