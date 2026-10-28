import Combine
import SwiftUI

@MainActor
final class BookmarksCoordinator: ObservableObject, BookmarksRouting {
    @Published var path = NavigationPath()

    func openPost(id: String) {
        path.append(BookmarksFlowRoute.postDetail(id: id))
    }
}
