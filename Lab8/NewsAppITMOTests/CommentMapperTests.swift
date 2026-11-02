import XCTest
@testable import NewsAppITMO

final class CommentMapperTests: XCTestCase {
    func testDecodesEntitiesAndPreservesLineBreaks() {
        XCTAssertEqual(map("<p>A &amp; B<br>next line</p>"), "A & B\nnext line")
        XCTAssertEqual(map("<p>&lt;tag&gt; &quot;quote&quot; &copy; &#169; &#x1F600;</p>"),
                       "<tag> \"quote\" © © 😀")
        XCTAssertEqual(map("<p>&amp;lt;tag&amp;gt;</p>"), "&lt;tag&gt;")
    }

    func testSeparatesParagraphsListsAndBlockQuotes() {
        XCTAssertEqual(map("<p>First</p><p>Second</p><ul><li>One</li><li>Two</li></ul>"),
                       "First\nSecond\nOne\nTwo")
        XCTAssertEqual(map("<blockquote>Quote</blockquote><div>Reply</div>"), "Quote\nReply")
        XCTAssertEqual(map("<p>First<p>Second"), "First\nSecond")
    }

    func testPreservesInlineAndPreformattedText() {
        XCTAssertEqual(map("<p>Привет, <strong>мир</strong>!</p>"), "Привет, мир!")
        XCTAssertEqual(map("<pre>first\n  second\n\nthird</pre>"), "first\n  second\n\nthird")
        XCTAssertEqual(map("<p>first<br><br/>second</p>"), "first\n\nsecond")
        XCTAssertEqual(map(""), "")
    }

    func testMapsRepliesAndSkipsNonVisibleHTML() {
        let child = dto("<p>Child &amp; reply<br>Next</p>")
        let result = CommentMapper.toDomain(dto(
            "<style>body { color: red }</style><p>Parent</p><!-- hidden --><script>ignored</script>",
            children: [child]
        ))
        XCTAssertEqual(result.text, "Parent")
        XCTAssertEqual(result.children.first?.text, "Child & reply\nNext")
        XCTAssertEqual(result.authorName, "Неизвестный автор")
    }

    private func map(_ html: String) -> String {
        CommentMapper.toDomain(dto(html)).text
    }

    private func dto(_ html: String, children: [CommentDTO] = []) -> CommentDTO {
        CommentDTO(idCode: "comment", createdAt: .distantPast, bodyHtml: html,
                   user: CommentUserDTO(name: nil, profileImage90: nil), children: children)
    }
}
