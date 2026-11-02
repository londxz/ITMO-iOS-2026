enum BlogFlowRoute: Hashable, Sendable {
    case postDetail(id: String)
    case authorProfile(id: String, username: String)
}
