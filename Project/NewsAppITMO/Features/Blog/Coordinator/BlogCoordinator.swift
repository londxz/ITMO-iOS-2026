import SwiftUI
import Combine

@MainActor
final class BlogCoordinator: ObservableObject, BlogRouting {
    @Published var path = NavigationPath()

    func openPost(id: String) {
        path.append(BlogFlowRoute.postDetail(id: id))
    }

    func openAuthor(id: String, username: String) {
        path.append(BlogFlowRoute.authorProfile(id: id, username: username))
    }
}
