enum PostDetailAction: Sendable {
    case onAppear
    case onDisappear
    case retry
    case refresh
    case toggleBookmark
    case didSelectAuthor
    case didSelectComments
    case dismissMessage
    case dismissRefreshError
}
