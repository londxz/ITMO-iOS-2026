enum PostDetailFlowRoute: Hashable, Identifiable {
    case author(id: String, username: String)

    var id: String {
        switch self {
        case .author(let id, let username): "author-\(id)-\(username)"
        }
    }
}

struct CommentsSheetRoute: Identifiable, Hashable {
    let postID: String
    var id: String { postID }
}
