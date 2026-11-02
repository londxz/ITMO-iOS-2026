import Foundation

protocol AuthorRepository: Sendable {
    func fetchAuthor(id: String) async throws -> AuthorModel

    func fetchPosts(
        username: String,
        page: Int,
        perPage: Int
    ) async throws -> [PostModel]
}

actor AuthorRepositoryImpl: AuthorRepository {
    private let client: any HTTPClient

    init(client: any HTTPClient) {
        self.client = client
    }

    func fetchAuthor(id: String) async throws -> AuthorModel {
        let dto: AuthorProfileDTO = try await client.send(AuthorEndpoint.profile(id: id))
        return AuthorMapper.toDomain(dto)
    }

    func fetchPosts(
        username: String,
        page: Int,
        perPage: Int
    ) async throws -> [PostModel] {
        let dtos: [ArticleDTO] = try await client.send(
            AuthorEndpoint.articles(username: username, page: page, perPage: perPage)
        )
        return dtos.map(ArticleMapper.toDomain)
    }
}
