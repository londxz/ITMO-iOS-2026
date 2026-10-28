enum BookmarksAction: Sendable {
    case onAppear
    case onDisappear
    case searchTextChanged(String)
    case delete(id: String)
    case didSelectPost(id: String)
    case retry
    case dismissMessage
}
