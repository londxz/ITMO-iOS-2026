import Combine

@MainActor
final class PostDetailCoordinator: ObservableObject, PostDetailRouting {
    @Published var authorRoute: PostDetailFlowRoute?
    @Published var commentsRoute: CommentsSheetRoute?

    func openAuthor(id: String, username: String) {
        authorRoute = .author(id: id, username: username)
    }

    func openComments(postID: String) {
        commentsRoute = CommentsSheetRoute(postID: postID)
    }
}
