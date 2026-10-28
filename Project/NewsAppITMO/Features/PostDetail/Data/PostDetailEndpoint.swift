enum PostDetailEndpoint: Endpoint {
    case post(id: String)

    var path: String {
        switch self {
        case .post(let id): "\(APIPath.articles)/\(id)"
        }
    }
}
