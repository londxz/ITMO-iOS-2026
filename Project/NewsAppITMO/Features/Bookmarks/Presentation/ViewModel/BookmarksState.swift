import Foundation

struct BookmarksState: Equatable, Sendable {
    var bookmarks: [PostModel] = []
    var searchText = ""
    var loadState: LoadState = .idle
    var deletingID: String?
    var message: String?

    var filteredBookmarks: [PostModel] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return bookmarks }
        return bookmarks.filter { post in
            post.title.localizedStandardContains(query)
                || post.author.name.localizedStandardContains(query)
                || post.tags.contains { $0.localizedStandardContains(query) }
        }
    }

    var isEmpty: Bool { bookmarks.isEmpty }
    var hasNoSearchResults: Bool { !isEmpty && filteredBookmarks.isEmpty }
}
