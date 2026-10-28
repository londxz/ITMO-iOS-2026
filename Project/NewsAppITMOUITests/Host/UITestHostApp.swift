import SwiftUI

/// Uses the production screens and repositories with test-only composition.
@main
struct UITestHostApp: App {
    @StateObject private var coordinator = AppCoordinator()
    private let container: AppContainer

    init() {
        guard let name = ProcessInfo.processInfo.environment["UITEST_SCENARIO"],
              let scenario = UITestScenario(rawValue: name) else {
            preconditionFailure("The UI test host requires a valid UITEST_SCENARIO")
        }
        let fileName = ProcessInfo.processInfo.environment["UITEST_BOOKMARKS_FILE"] ?? UUID().uuidString
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        if scenario == .postDetailOffline {
            let saved = PostModel(
                id: "1", title: "Сохранённая статья", summary: "", bodyMarkdown: "## Офлайн-текст\n\nПолная сохранённая статья.",
                publishedAt: .now, coverImageURL: nil, readingTimeMinutes: 3,
                reactionsCount: 2, commentsCount: 1, tags: ["swift"],
                author: AuthorModel(id: "1", username: "test-author", name: "Автор", avatarURL: nil,
                                    bio: nil, location: nil, websiteURL: nil, joinedAt: nil),
                webURL: URL(string: "https://dev.to/test-author/post-1")
            )
            try! JSONEncoder().encode([saved]).write(to: fileURL)
        }
        container = AppContainer(
            httpClient: MockHTTPClient(scenario: scenario),
            bookmarksStorage: FileBookmarksStorage(fileURL: fileURL)
        )
    }

    var body: some Scene {
        WindowGroup {
            AppRootTabView(coordinator: coordinator, container: container)
        }
    }
}
