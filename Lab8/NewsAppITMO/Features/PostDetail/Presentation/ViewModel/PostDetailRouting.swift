@MainActor
protocol PostDetailRouting: AnyObject {
    func openAuthor(id: String, username: String)
    func openComments(postID: String)
}
