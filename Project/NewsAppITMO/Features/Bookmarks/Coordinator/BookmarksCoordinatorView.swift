import SwiftUI

struct BookmarksCoordinatorView: View {
    @ObservedObject var coordinator: BookmarksCoordinator
    let storage: any BookmarksStorage
    let imageCache: any ImageCache
    let screenFactory: any ScreenFactory

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            BookmarksView(
                viewModel: BookmarksViewModel(storage: storage, router: coordinator),
                imageCache: imageCache
            )
            .navigationDestination(for: BookmarksFlowRoute.self) { route in
                switch route {
                case .postDetail(let id):
                    screenFactory.makePostDetailView(id: id)
                }
            }
        }
    }
}
