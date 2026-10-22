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
        launch(.loading)
        let loading = app.activityIndicators.firstMatch
        XCTAssertTrue(loading.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.scrollViews.firstMatch.exists)
        XCTAssertFalse(app.buttons["Повторить"].exists)
    }

    func testFeedShowsHeroAndFreshPostsWithoutDuplicatingHero() {
        launch(.success)
        let hero = post(1)
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        XCTAssertTrue(hero.label.contains("Новость 001"))
        XCTAssertTrue(post(2).exists)
        XCTAssertTrue(post(3).exists)
        XCTAssertEqual(posts(1).count, 1)
        XCTAssertFalse(app.buttons["Не удалось загрузить. Повторить"].exists)
    }

    func testEmptyFeed() {
        launch(.empty)
        XCTAssertTrue(app.staticTexts["Новостей пока нет"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.scrollViews.firstMatch.exists)
        XCTAssertFalse(post(1).exists)
        XCTAssertFalse(app.buttons["Повторить"].exists)
    }

    func testInitialErrorCanBeRetried() {
        launch(.initialErrorThenSuccess)
        let retry = app.buttons["Повторить"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Нет подключения"].exists)
        retry.tap()

        XCTAssertTrue(post(2).waitForExistence(timeout: 5))
        XCTAssertTrue(retry.waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Нет подключения"].exists)
    }

    func testScrollingLoadsNextPage() {
        launch(.pagination)
        let first = post(2)
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let nextPagePost = post(23)
        scrollTo(nextPagePost)
        XCTAssertTrue(nextPagePost.label.contains("Новость 023"))
        XCTAssertEqual(posts(23).count, 1)
        XCTAssertFalse(app.buttons["Не удалось загрузить. Повторить"].exists)
    }

    func testPaginationErrorCanBeRetried() {
        launch(.paginationErrorThenSuccess)
        XCTAssertTrue(post(1).waitForExistence(timeout: 5))
        let retry = app.buttons["Не удалось загрузить. Повторить"]
        scrollTo(retry)
        // The existing page stays on screen while the next page has an error.
        XCTAssertTrue(post(20).exists)
        XCTAssertFalse(app.buttons["Повторить"].exists)
        retry.tap()

        let nextPagePost = post(23)
        scrollTo(nextPagePost)
        XCTAssertTrue(nextPagePost.exists)
        XCTAssertTrue(retry.waitForNonExistence(timeout: 5))
    }

    func testPullToRefreshReplacesFeed() {
        launch(.refresh)
        let original = post(titled: "До обновления")
        XCTAssertTrue(original.waitForExistence(timeout: 5))
        XCTAssertTrue(original.label.contains("До обновления"))
        let feed = app.scrollViews.firstMatch
        let start = feed.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        let end = feed.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        start.press(forDuration: 0.1, thenDragTo: end)

        let refreshed = post(titled: "После обновления")
        XCTAssertTrue(refreshed.waitForExistence(timeout: 5))
        XCTAssertTrue(refreshed.label.contains("После обновления"))
        XCTAssertTrue(original.waitForNonExistence(timeout: 5))
    }

    func testHeroOpensCorrectPostAndBackReturnsToFeed() {
        launch(.success)
        openPostAndReturn(id: 1)
    }

    func testFreshPostOpensCorrectPostAndBackReturnsToFeed() {
        launch(.success)
        openPostAndReturn(id: 2)
    }

    func testSwitchingTabsAndReturningToNews() {
        launch(.success)
        XCTAssertTrue(post(1).waitForExistence(timeout: 5))
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
        XCTAssertTrue(post(1).waitForExistence(timeout: 5))
        XCTAssertTrue(post(2).exists)
    }

    private func posts(_ id: Int) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", String(format: "Новость %03d", id)))
    }

    private func post(_ id: Int) -> XCUIElement {
        posts(id).firstMatch
    }

    private func post(titled title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
    }

    private func launch(_ scenario: UITestScenario) {
        app.launchArguments = ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launchEnvironment["UITEST_SCENARIO"] = scenario.rawValue
        app.launch()
    }

    private func scrollTo(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let feed = app.scrollViews.firstMatch
        XCTAssertTrue(feed.waitForExistence(timeout: 5), file: file, line: line)
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            feed.swipeUp()
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(element.isHittable, file: file, line: line)
    }

    private func openPostAndReturn(id: Int) {
        let button = post(id)
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        let detail = app.staticTexts["Детали публикации ID: \(id)"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertEqual(detail.label, "Детали публикации ID: \(id)")
        app.navigationBars["Публикация"].buttons.firstMatch.tap()
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertTrue(detail.waitForNonExistence(timeout: 5))
    }
}
