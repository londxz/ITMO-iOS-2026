import Foundation

/// In-process fixtures for UI automation. No requests or remote images are used.
/// Compiled only into the UI test host, never into the production application.
actor MockHTTPClient: HTTPClient {

    private let scenario: UITestScenario
    private var attempts: [Int: Int] = [:]
    private var detailAttempts = 0

    init(scenario: UITestScenario) {
        self.scenario = scenario
    }

    func send<T: Decodable & Sendable>(_ endpoint: any Endpoint) async throws -> T {
        if let endpoint = endpoint as? PostDetailEndpoint,
           case .post(let id) = endpoint {
            detailAttempts += 1
            if scenario == .postDetailOffline || (scenario == .postDetailErrorThenSuccess && detailAttempts == 1) {
                throw NetworkError.transport(.notConnectedToInternet)
            }
            var detail = article(Int(id) ?? 1)
            if scenario == .postDetailRefresh && detailAttempts > 1 {
                detail["title"] = "Обновлённая статья"
            }
            detail["tag_list"] = "news, swift"
            detail["url"] = "https://dev.to/test-author/post-\(id)"
            detail["body_markdown"] = scenario == .postDetailEmptyBody ? "" : """
                ## Раздел статьи

                Текст с **выделением** и [ссылкой](https://dev.to).

                - Первый пункт
                - Второй пункт

                ```swift
                let value = 1
                ```

                {% unsupported example %}
                """
            let data = try JSONSerialization.data(withJSONObject: detail)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        }

        if let endpoint = endpoint as? CommentsEndpoint,
           case .comments(let postID) = endpoint {
            let comments: [[String: Any]] = [[
                "id_code": "comment-\(postID)",
                "created_at": "2026-10-01T12:00:00Z",
                "body_html": "<p>Публикация ID: \(postID)</p><p>A &amp; B<br>next line</p>",
                "user": ["name": "Автор комментария"],
                "children": []
            ]]
            let data = try JSONSerialization.data(withJSONObject: comments)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        }

        guard let endpoint = endpoint as? NewsEndpoint else {
            throw NetworkError.invalidURL
        }

        if scenario == .loading {
            // Keep the loading screen observable until the test terminates the app.
            try await Task.sleep(for: .seconds(60))
        }

        let articles: [[String: Any]]
        switch endpoint {
        case .dayTop:
            switch scenario {
            case .empty, .initialErrorThenSuccess, .refresh:
                articles = []
            default:
                articles = [article(1)]
            }
        case .fresh(let page, _):
            attempts[page, default: 0] += 1
            let attempt = attempts[page, default: 0]
            switch scenario {
            case .empty:
                articles = []
            case .initialErrorThenSuccess where attempt == 1:
                throw NetworkError.transport(.notConnectedToInternet)
            case .paginationErrorThenSuccess where page == 2 && attempt == 1:
                throw NetworkError.serverUnavailable(statusCode: 503)
            case .pagination, .paginationErrorThenSuccess:
                switch page {
                case 1: articles = (1...20).map { article($0) }
                case 2: articles = (21...23).map { article($0) }
                default: articles = []
                }
            case .refresh:
                articles = attempt == 1
                    ? [article(101, title: "До обновления")]
                    : [article(201, title: "После обновления")]
            default:
                articles = [article(1), article(2), article(3)]
            }
        }

        let data = try JSONSerialization.data(withJSONObject: articles)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func article(_ id: Int, title: String? = nil) -> [String: Any] {
        [
            "id": id,
            "title": title ?? String(format: "Новость %03d", id),
            "description": "Описание новости \(id)",
            "published_at": "2026-10-01T12:00:00Z",
            "reading_time_minutes": 3,
            "public_reactions_count": 2,
            "comments_count": 1,
            "tag_list": ["news"],
            "user": ["user_id": 1, "name": "Тестовый автор", "username": "test-author"]
        ]
    }
}
