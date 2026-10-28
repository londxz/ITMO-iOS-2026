protocol PostDetailRepository: Sendable {
    func fetchPost(id: String) async throws -> PostModel
}

actor PostDetailRepositoryImpl: PostDetailRepository {
    private let client: any HTTPClient

    init(client: any HTTPClient) {
        self.client = client
    }

    func fetchPost(id: String) async throws -> PostModel {
        let dto: ArticleDTO = try await client.send(PostDetailEndpoint.post(id: id))
        return ArticleMapper.toDomain(dto)
    }
}
