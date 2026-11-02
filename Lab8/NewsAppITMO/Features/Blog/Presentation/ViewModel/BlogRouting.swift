@MainActor
protocol BlogRouting: AnyObject {
    func openPost(id: String)
    func openAuthor(id: String, username: String)
}
