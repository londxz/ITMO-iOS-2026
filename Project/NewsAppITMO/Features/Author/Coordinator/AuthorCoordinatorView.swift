import SwiftUI

struct AuthorCoordinatorView: View {
    @StateObject private var coordinator: AuthorCoordinator
    private let authorID: String?
    private let username: String
    private let repository: any AuthorRepository
    private let imageCache: any ImageCache
    private let screenFactory: any ScreenFactory

    init(
        authorID: String?,
        username: String,
        coordinator: AuthorCoordinator,
        repository: any AuthorRepository,
        imageCache: any ImageCache,
        screenFactory: any ScreenFactory
    ) {
        self.authorID = authorID
        self.username = username
        _coordinator = StateObject(wrappedValue: coordinator)
        self.repository = repository
        self.imageCache = imageCache
        self.screenFactory = screenFactory
    }

    var body: some View {
        AuthorProfileView(
            viewModel: AuthorProfileViewModel(
                authorID: authorID,
                username: username,
                repository: repository,
                router: coordinator
            ),
            imageCache: imageCache
        )
        .navigationDestination(item: $coordinator.route) { route in
            switch route {
            case .postDetail(let id):
                screenFactory.makePostDetailView(id: id)
            }
        }
    }
}
