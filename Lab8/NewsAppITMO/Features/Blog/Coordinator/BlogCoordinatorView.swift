import SwiftUI

struct BlogCoordinatorView: View {
    @ObservedObject var coordinator: BlogCoordinator
    let screenFactory: any ScreenFactory
    let repository: any BlogRepository
    let imageCache: any ImageCache

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            BlogView(
                viewModel: BlogViewModel(
                    repository: repository,
                    router: coordinator
                ),
                imageCache: imageCache
            )
            .navigationDestination(for: BlogFlowRoute.self) { route in
                switch route {
                case .postDetail(let id):
                    screenFactory.makePostDetailView(id: id)
                case .authorProfile(let id, let username):
                    screenFactory.makeAuthorProfileView(id: id, username: username)
                }
            }
        }
    }
}
