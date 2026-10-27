protocol CommentsRepository: Sendable {
    func fetchComments(postID: String) async throws -> [CommentModel]
}

actor CommentsRepositoryImpl: CommentsRepository {
    private let client: any HTTPClient

    init(client: any HTTPClient) {
        self.client = client
    }

    func fetchComments(postID: String) async throws -> [CommentModel] {
        let dtos: [CommentDTO] = try await client.send(
            CommentsEndpoint.comments(postID: postID)
        )
        return dtos.map(CommentMapper.toDomain)
    }
}
