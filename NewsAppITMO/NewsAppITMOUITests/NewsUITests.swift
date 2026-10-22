import XCTest

@MainActor
final class NewsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        if let app {
            if let testRun, testRun.failureCount > 0 {
                let attachment = XCTAttachment(screenshot: app.screenshot())
                attachment.lifetime = .keepAlways
                add(attachment)
            }
            app.terminate()
        }
        app = nil
    }

    func testLoadingIndicator() {
        launch("loading")
        let loading = app.descendants(matching: .any).matching(identifier: "news.loading").firstMatch
        XCTAssertTrue(loading.waitForExistence(timeout: 5))
        XCTAssertFalse(app.scrollViews["news.feed"].exists)
        XCTAssertFalse(app.buttons["error.retry"].exists)
    }

    func testFeedShowsHeroAndFreshPostsWithoutDuplicatingHero() {
        launch("success")
        let hero = app.buttons["news.hero.1"]
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        XCTAssertTrue(hero.label.contains("Новость 1"))
        XCTAssertTrue(app.buttons["news.post.2"].exists)
        XCTAssertTrue(app.buttons["news.post.3"].exists)
        XCTAssertEqual(app.buttons.matching(identifier: "news.post.1").count, 0)
        XCTAssertFalse(app.buttons["news.pagination.retry"].exists)
    }

    func testEmptyFeed() {
        launch("empty")
        XCTAssertTrue(app.staticTexts["Новостей пока нет"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.scrollViews["news.feed"].exists)
        XCTAssertFalse(app.buttons["news.hero.1"].exists)
        XCTAssertFalse(app.buttons["error.retry"].exists)
    }

    func testInitialErrorCanBeRetried() {
        launch("initialErrorThenSuccess")
        let retry = app.buttons["error.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Нет подключения"].exists)
        retry.tap()

        XCTAssertTrue(app.buttons["news.post.2"].waitForExistence(timeout: 5))
        XCTAssertFalse(retry.exists)
        XCTAssertFalse(app.staticTexts["Нет подключения"].exists)
    }

    func testScrollingLoadsNextPage() {
        launch("pagination")
        let first = app.buttons["news.post.2"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let nextPagePost = app.buttons["news.post.23"]
        scrollTo(nextPagePost)
        XCTAssertTrue(nextPagePost.label.contains("Новость 23"))
        XCTAssertEqual(app.buttons.matching(identifier: "news.post.23").count, 1)
        XCTAssertFalse(app.buttons["news.pagination.retry"].exists)
    }

    func testPaginationErrorCanBeRetried() {
        launch("paginationErrorThenSuccess")
        XCTAssertTrue(app.buttons["news.hero.1"].waitForExistence(timeout: 5))
        let retry = app.buttons["news.pagination.retry"]
        scrollTo(retry)
        // The existing page stays on screen while the next page has an error.
        XCTAssertTrue(app.buttons["news.post.20"].exists)
        XCTAssertFalse(app.buttons["error.retry"].exists)
        retry.tap()

        let nextPagePost = app.buttons["news.post.23"]
        scrollTo(nextPagePost)
        XCTAssertTrue(nextPagePost.exists)
        XCTAssertFalse(retry.exists)
    }

    func testPullToRefreshReplacesFeed() {
        launch("refresh")
        let original = app.buttons["news.post.101"]
        XCTAssertTrue(original.waitForExistence(timeout: 5))
        XCTAssertTrue(original.label.contains("До обновления"))
        let feed = app.scrollViews["news.feed"]
        let start = feed.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        let end = feed.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        start.press(forDuration: 0.1, thenDragTo: end)

        let refreshed = app.buttons["news.post.201"]
        XCTAssertTrue(refreshed.waitForExistence(timeout: 5))
        XCTAssertTrue(refreshed.label.contains("После обновления"))
        XCTAssertFalse(original.exists)
    }

    func testHeroOpensCorrectPostAndBackReturnsToFeed() {
        launch("success")
        openPostAndReturn(buttonID: "news.hero.1", postID: "1")
    }

    func testFreshPostOpensCorrectPostAndBackReturnsToFeed() {
        launch("success")
        openPostAndReturn(buttonID: "news.post.2", postID: "2")
    }

    func testSwitchingTabsAndReturningToNews() {
        launch("success")
        XCTAssertTrue(app.buttons["news.hero.1"].waitForExistence(timeout: 5))
        let tabs = app.tabBars
        for (name, text) in [
            ("Блог", "Здесь будут статьи блога"),
            ("Закладки", "Здесь будут сохраненные статьи"),
            ("Настройки", "Здесь будут настройки приложения")
        ] {
            tabs.buttons[name].tap()
            XCTAssertTrue(app.staticTexts[text].waitForExistence(timeout: 5))
        }
        tabs.buttons["Новости"].tap()
        XCTAssertTrue(app.buttons["news.hero.1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["news.post.2"].exists)
    }

    private func launch(_ scenario: String) {
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launchEnvironment["UITEST_SCENARIO"] = scenario
        app.launch()
    }

    private func scrollTo(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let feed = app.scrollViews["news.feed"]
        XCTAssertTrue(feed.waitForExistence(timeout: 5), file: file, line: line)
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            feed.swipeUp()
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(element.isHittable, file: file, line: line)
    }

    private func openPostAndReturn(buttonID: String, postID: String) {
        let button = app.buttons[buttonID]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        let detail = app.staticTexts["post.detail.id"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertEqual(detail.label, "Детали публикации ID: \(postID)")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertFalse(detail.exists)
    }
}
