import SwiftUI
import Combine

@MainActor
final class AuthorCoordinator: ObservableObject, AuthorRouting {
    @Published var route: AuthorFlowRoute?

    func openPost(id: String) {
        route = .postDetail(id: id)
    }
}
