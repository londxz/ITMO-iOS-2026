import Foundation

enum CommentsEndpoint: Endpoint {
    case comments(postID: String)

    var path: String { APIPath.comments }

    var queryItems: [URLQueryItem] {
        switch self {
        case .comments(let postID):
            [URLQueryItem(name: "a_id", value: postID)]
        }
    }
}
