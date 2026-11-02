import SwiftUI

struct PostDetailCoordinatorView: View {
    @StateObject private var coordinator: PostDetailCoordinator
    private let postID: String
    private let repository: any PostDetailRepository
    private let bookmarksStorage: any BookmarksStorage
    private let imageCache: any ImageCache
    private let screenFactory: any ScreenFactory

    init(
        postID: String,
        coordinator: PostDetailCoordinator,
        repository: any PostDetailRepository,
        bookmarksStorage: any BookmarksStorage,
        imageCache: any ImageCache,
        screenFactory: any ScreenFactory
    ) {
        self.postID = postID
        _coordinator = StateObject(wrappedValue: coordinator)
        self.repository = repository
        self.bookmarksStorage = bookmarksStorage
        self.imageCache = imageCache
        self.screenFactory = screenFactory
    }

    var body: some View {
        PostDetailView(
            viewModel: PostDetailViewModel(
                postID: postID,
                repository: repository,
                bookmarksStorage: bookmarksStorage,
                router: coordinator
            ),
            imageCache: imageCache
        )
        .navigationDestination(item: $coordinator.authorRoute) { route in
            switch route {
            case .author(let id, let username):
                screenFactory.makeAuthorProfileView(id: id, username: username)
            }
        }
        .sheet(item: $coordinator.commentsRoute) { route in
            screenFactory.makeCommentsSheet(postID: route.postID)
        }
    }
}
