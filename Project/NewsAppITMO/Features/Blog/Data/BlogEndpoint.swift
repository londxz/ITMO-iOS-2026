import Foundation

enum BlogEndpoint: Endpoint {
    case tags(perPage: Int)
    case articles(
        tag: String?,
        sort: BlogSort,
        page: Int,
        perPage: Int
    )

    var path: String {
        switch self {
        case .tags:
            APIPath.tags
        case .articles:
            APIPath.articles
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .tags(let perPage):
            return [URLQueryItem(name: "per_page", value: "\(perPage)")]
        case .articles(let tag, let sort, let page, let perPage):
            var items: [URLQueryItem] = []
            if let tag {
                items.append(URLQueryItem(name: "tag", value: tag))
            }
            items.append(sort.queryItem)
            items.append(URLQueryItem(name: "page", value: "\(page)"))
            items.append(URLQueryItem(name: "per_page", value: "\(perPage)"))
            return items
        }
    }
}

private extension BlogSort {
    var queryItem: URLQueryItem {
        switch self {
        case .fresh:
            URLQueryItem(name: "state", value: "fresh")
        case .topWeek:
            URLQueryItem(name: "top", value: "7")
        case .topMonth:
            URLQueryItem(name: "top", value: "30")
        }
    }
}
