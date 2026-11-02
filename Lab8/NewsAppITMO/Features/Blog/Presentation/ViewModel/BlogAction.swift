enum BlogAction: Sendable {
    case onAppear
    case onDisappear
    case refresh
    case loadMore
    case selectTag(BlogTagModel?)
    case selectSort(BlogSort)
    case didSelectPost(id: String)
    case didSelectAuthor(id: String, username: String)
}
