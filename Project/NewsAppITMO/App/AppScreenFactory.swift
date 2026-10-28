//
//  AppScreenFactory.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import SwiftUI

@MainActor
final class AppScreenFactory: ScreenFactory {
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    func makePostDetailView(id: String) -> AnyView {
        let repository = PostDetailRepositoryImpl(client: container.httpClient)
        return AnyView(PostDetailCoordinatorView(
            postID: id,
            coordinator: PostDetailCoordinator(),
            repository: repository,
            bookmarksStorage: container.bookmarksStorage,
            imageCache: container.imageCache,
            screenFactory: self
        ))
    }

    func makeAuthorProfileView(id: String, username: String) -> AnyView {
        // это просто пример, тут будет собираться экран из частей (view viewmodel repository)
        AnyView(
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.purple)
                Text("Профиль автора @\(username)")
                    .font(.title2).bold()
                Text("ID: \(id)")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Автор")
            .navigationBarTitleDisplayMode(.inline)
        )
    }

    func makeCommentsSheet(postID: String) -> AnyView {
        let repository = CommentsRepositoryImpl(client: container.httpClient)
        return AnyView(
            CommentsSheetView(
                viewModel: CommentsViewModel(postID: postID, repository: repository),
                imageCache: container.imageCache
            )
        )
    }
}
