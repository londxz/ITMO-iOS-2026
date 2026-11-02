enum AuthorAction: Sendable {
    case onAppear
    case onDisappear
    case refresh
    case loadMore
    case didSelectPost(id: String)
}
