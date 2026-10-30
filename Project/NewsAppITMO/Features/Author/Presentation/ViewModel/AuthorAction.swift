enum AuthorAction: Sendable {
    case onAppear
    case onDisappear
    case refresh
    case loadMore
    case dismissRefreshError
    case didSelectPost(id: String)
}
