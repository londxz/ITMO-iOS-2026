import Foundation

enum AuthorEndpoint: Endpoint {
    case profile(id: String)
    case profileByUsername(String)
    case articles(username: String, page: Int, perPage: Int)

    var path: String {
        switch self {
        case .profile(let id):
            "\(APIPath.users)/\(id)"
        case .profileByUsername:
            "\(APIPath.users)/by_username"
        case .articles:
            APIPath.articles
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .profile:
            []
        case .profileByUsername(let username):
            [URLQueryItem(name: "url", value: username)]
        case .articles(let username, let page, let perPage):
            [
                URLQueryItem(name: "username", value: username),
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "per_page", value: "\(perPage)")
            ]
        }
    }
}
