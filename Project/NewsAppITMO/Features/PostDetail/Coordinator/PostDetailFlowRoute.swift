enum PostDetailFlowRoute: Hashable, Identifiable {
    case author(id: String?, username: String)

    var id: String {
        switch self {
        case .author(_, let username): "author-\(username)"
        }
    }
}

struct CommentsSheetRoute: Identifiable, Hashable {
    let postID: String
    var id: String { postID }
}
