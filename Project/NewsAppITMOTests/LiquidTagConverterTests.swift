import XCTest
@testable import NewsAppITMO

final class LiquidTagConverterTests: XCTestCase {
    func testLeavesMarkdownWithoutTagsUntouched() {
        let markdown = "# Заголовок\n\nТекст со [ссылкой](https://dev.to) и `кодом`."
        XCTAssertEqual(LiquidTagConverter.convert(markdown), markdown)
    }

    func testTurnsUrlEmbedsIntoLinks() {
        XCTAssertEqual(
            LiquidTagConverter.convert("{% embed https://dev.to/author/post-1 %}"),
            "[https://dev.to/author/post-1](<https://dev.to/author/post-1>)"
        )
        XCTAssertEqual(
            LiquidTagConverter.convert("Смотрите: {% link \"https://dev.to/a/b\" %} и дальше"),
            "Смотрите: [https://dev.to/a/b](<https://dev.to/a/b>) и дальше"
        )
    }

    func testBuildsLinksForIdBasedEmbeds() {
        XCTAssertEqual(
            LiquidTagConverter.convert("{% github apple/swift no-readme %}"),
            "[https://github.com/apple/swift](<https://github.com/apple/swift>)"
        )
        XCTAssertEqual(
            LiquidTagConverter.convert("{% youtube dQw4w9WgXcQ %}"),
            "[https://www.youtube.com/watch?v=dQw4w9WgXcQ](<https://www.youtube.com/watch?v=dQw4w9WgXcQ>)"
        )
        XCTAssertEqual(
            LiquidTagConverter.convert("{% EMBED https://example.com %}"),
            "[https://example.com](<https://example.com>)"
        )
    }

    func testLinksUsersAndTags() {
        XCTAssertEqual(
            LiquidTagConverter.convert("{% user ben %} пишет про {% tag swift %}"),
            "[@ben](<https://dev.to/ben>) пишет про [#swift](<https://dev.to/t/swift>)"
        )
    }

    func testTurnsDetailsIntoBoldSummaryAndDropsClosingTags() {
        XCTAssertEqual(
            LiquidTagConverter.convert("{% details Ответ %}\nСкрытый текст\n{% enddetails %}"),
            "**Ответ**\nСкрытый текст\n"
        )
    }

    func testTurnsCallToActionIntoLink() {
        XCTAssertEqual(
            LiquidTagConverter.convert("{% cta https://dev.to/join %} Присоединиться {% endcta %}"),
            "[Присоединиться](<https://dev.to/join>)"
        )
    }

    func testDropsUnknownTagsButKeepsTheirContent() {
        XCTAssertEqual(LiquidTagConverter.convert("{% raw %}{{ value }}{% endraw %}"), "{{ value }}")
        XCTAssertEqual(LiquidTagConverter.convert("{% katex %}x^2{% endkatex %}"), "x^2")
        XCTAssertEqual(LiquidTagConverter.convert("{% unknown something %}"), "")
    }

    func testKeepsTagsInsideCode() {
        let fenced = "```liquid\n{% embed https://dev.to/a/b %}\n```\n{% embed https://dev.to/c/d %}"
        XCTAssertEqual(
            LiquidTagConverter.convert(fenced),
            "```liquid\n{% embed https://dev.to/a/b %}\n```\n[https://dev.to/c/d](<https://dev.to/c/d>)"
        )
        let inline = "Тег `{% raw %}` нужен в Jekyll"
        XCTAssertEqual(LiquidTagConverter.convert(inline), inline)
    }
}
