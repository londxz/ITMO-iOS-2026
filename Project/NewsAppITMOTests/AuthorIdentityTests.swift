import XCTest
@testable import NewsAppITMO

final class AuthorIdentityTests: XCTestCase {
    func testMapperKeepsRealAuthorID() throws {
        let author = try mapAuthor(userJSON: #"{"name":"Author","username":"author","user_id":42}"#)
        XCTAssertEqual(author.id, "42")
    }

    func testMapperLeavesMissingAuthorIDEmptyInsteadOfInventingOne() throws {
        let author = try mapAuthor(userJSON: #"{"name":"Author","username":"author"}"#)
        XCTAssertNil(author.id)
        XCTAssertEqual(author.username, "author")
    }

    func testRepositoryRequestsProfileByRealID() async throws {
        let client = ProfileRecordingClient()
        let author = try await AuthorRepositoryImpl(client: client).fetchAuthor(id: "42", username: "author")
        let requests = await client.requests
        XCTAssertEqual(requests, [RecordedRequest(path: "users/42", queryItems: [])])
        XCTAssertEqual(author.id, "42")
    }

    func testRepositoryRequestsProfileByUsernameWhenIDIsMissing() async throws {
        let client = ProfileRecordingClient()
        let author = try await AuthorRepositoryImpl(client: client).fetchAuthor(id: nil, username: "author")
        let requests = await client.requests
        XCTAssertEqual(
            requests,
            [RecordedRequest(path: "users/by_username", queryItems: [URLQueryItem(name: "url", value: "author")])]
        )
        XCTAssertEqual(author.username, "author")
    }

    @MainActor
    func testProfileScreenWithoutIDLoadsAuthorByUsername() async {
        let repository = AuthorRecordingRepository()
        let viewModel = AuthorProfileViewModel(authorID: nil, username: "author", repository: repository, router: nil)
        await viewModel.send(.onAppear)?.value
        let calls = await repository.authorCalls
        XCTAssertEqual(calls, [AuthorCall(id: nil, username: "author")])
        XCTAssertEqual(viewModel.state.initialLoad, .loaded)
        XCTAssertEqual(viewModel.state.author?.username, "author")
    }

    func testLegacyBookmarkWithFabricatedZeroIDDecodesWithoutID() throws {
        let data = Data(#"{"id":"0","username":"author","name":"Author"}"#.utf8)
        let author = try JSONDecoder().decode(AuthorModel.self, from: data)
        XCTAssertNil(author.id)
        XCTAssertEqual(author.username, "author")
    }

    func testStoredAuthorKeepsAllFieldsAfterRoundTrip() throws {
        let author = AuthorModel(
            id: "7",
            username: "author",
            name: "Author",
            avatarURL: URL(string: "https://example.com/avatar.png"),
            bio: "Bio",
            location: "Earth",
            websiteURL: URL(string: "https://example.com"),
            joinedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let decoded = try JSONDecoder().decode(AuthorModel.self, from: JSONEncoder().encode(author))
        XCTAssertEqual(decoded, author)
    }

    private func mapAuthor(userJSON: String) throws -> AuthorModel {
        let data = Data("""
            {"id":1,"title":"Article","published_at":"2026-10-01T12:00:00Z",
             "reading_time_minutes":3,"public_reactions_count":2,"comments_count":1,
             "tag_list":["news"],"user":\(userJSON)}
            """.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return ArticleMapper.toDomain(try decoder.decode(ArticleDTO.self, from: data)).author
    }
}

private struct RecordedRequest: Equatable, Sendable {
    let path: String
    let queryItems: [URLQueryItem]
}

private struct AuthorCall: Equatable, Sendable {
    let id: String?
    let username: String
}

private actor ProfileRecordingClient: HTTPClient {
    private(set) var requests: [RecordedRequest] = []

    func send<T: Decodable & Sendable>(_ endpoint: any Endpoint) async throws -> T {
        requests.append(RecordedRequest(path: endpoint.path, queryItems: endpoint.queryItems))
        let data = Data(#"{"id":42,"username":"author","name":"Author"}"#.utf8)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

private actor AuthorRecordingRepository: AuthorRepository {
    private(set) var authorCalls: [AuthorCall] = []

    func fetchAuthor(id: String?, username: String) async throws -> AuthorModel {
        authorCalls.append(AuthorCall(id: id, username: username))
        return AuthorModel(
            id: "42", username: username, name: "Author",
            avatarURL: nil, bio: nil, location: nil, websiteURL: nil, joinedAt: nil
        )
    }

    func fetchPosts(username: String, page: Int, perPage: Int) async throws -> [PostModel] {
        []
    }
}
