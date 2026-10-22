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
        // это просто пример, тут будет собираться экран из частей (view viewmodel repository)
        AnyView(
            VStack(spacing: 16) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue)
                Text("Детали публикации ID: \(id)")
                    .font(.title2).bold()
                Text("Здесь будет текст статьи и кнопка автора")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Публикация")
            .navigationBarTitleDisplayMode(.inline)
        )
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
        // это просто пример, тут будет собираться экран из частей (view viewmodel repository)
        AnyView(
            VStack(spacing: 16) {
                Text("Комментарии к посту \(postID)")
                    .font(.headline)
            }
            .presentationDetents([.medium, .large])
        )
    }
}
