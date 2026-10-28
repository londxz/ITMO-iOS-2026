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

    func testCommentsOpenForEachSelectedPost() {
        launch(.success)
        for id in [1, 2] {
            let article = post(id)
            XCTAssertTrue(article.waitForExistence(timeout: 5))
            article.tap()
            let comments = app.buttons.matching(identifier: "1 комментариев").firstMatch
            XCTAssertTrue(comments.waitForExistence(timeout: 5))
            scrollTo(comments)
            comments.tap()

            XCTAssertTrue(app.navigationBars["Комментарии (1)"].waitForExistence(timeout: 5))
            let text = app.staticTexts["Публикация ID: \(id)\nA & B\nnext line"]
            XCTAssertTrue(text.waitForExistence(timeout: 5), app.debugDescription)
            app.buttons["Готово"].tap()
            XCTAssertTrue(text.waitForNonExistence(timeout: 5))
            app.navigationBars["Публикация"].buttons.firstMatch.tap()
        }
    }

    func testPostDetailShowsMarkdownAndTogglesBookmark() {
        launch(.success)
        XCTAssertTrue(post(1).waitForExistence(timeout: 5))
        post(1).tap()
        let title = app.staticTexts["post-detail-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Новость 001")
        scrollTo(app.staticTexts["Раздел статьи"])
        XCTAssertTrue(app.staticTexts["Раздел статьи"].exists)
        scrollTo(app.staticTexts["Первый пункт"])
        XCTAssertTrue(app.staticTexts["Первый пункт"].exists)

        let bookmark = app.buttons["post-detail-bookmark"]
        XCTAssertEqual(bookmark.label, "Сохранить в закладки")
        bookmark.tap()
        XCTAssertTrue(app.buttons["Удалить из закладок"].waitForExistence(timeout: 5))
        bookmark.tap()
        XCTAssertTrue(app.buttons["Сохранить в закладки"].waitForExistence(timeout: 5))
    }

    func testPostDetailRoutesToAuthorAndReturns() {
        launch(.success)
        XCTAssertTrue(post(1).waitForExistence(timeout: 5))
        post(1).tap()
        let author = app.buttons["post-detail-author"]
        XCTAssertTrue(author.waitForExistence(timeout: 5))
        scrollTo(author)
        author.tap()
        XCTAssertTrue(app.staticTexts["Профиль автора @test-author"].waitForExistence(timeout: 5))
        app.navigationBars["Автор"].buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["post-detail-title"].waitForExistence(timeout: 5))
    }

    func testPostDetailRetryAndEmptyMarkdown() {
        launch(.postDetailErrorThenSuccess)
        XCTAssertTrue(post(1).waitForExistence(timeout: 5))
        post(1).tap()
        let retry = app.buttons["Повторить"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        retry.tap()
        XCTAssertTrue(app.staticTexts["post-detail-title"].waitForExistence(timeout: 5))

        app.terminate()
        launch(.postDetailEmptyBody)
        XCTAssertTrue(post(1).waitForExistence(timeout: 5))
        post(1).tap()
        scrollTo(app.staticTexts["Текст статьи пока недоступен"])
        XCTAssertTrue(app.staticTexts["Текст статьи пока недоступен"].exists)
    }

    func testSavedPostDetailOpensWhenNetworkFails() {
        launch(.postDetailOffline)
        XCTAssertTrue(post(1).waitForExistence(timeout: 5))
        post(1).tap()
        let title = app.staticTexts["post-detail-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Сохранённая статья")
        scrollTo(app.staticTexts["Офлайн-текст"])
        XCTAssertTrue(app.staticTexts["Офлайн-текст"].exists)
        XCTAssertTrue(app.buttons["Удалить из закладок"].exists)
        XCTAssertFalse(app.buttons["Повторить"].exists)
    }

    func testPostDetailShareLinkOpensSystemSheet() {
        launch(.success)
        XCTAssertTrue(post(1).waitForExistence(timeout: 5))
        post(1).tap()
        let share = app.buttons["Поделиться"]
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        share.tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 5), app.debugDescription)
    }

    func testPostDetailPullToRefreshUpdatesArticle() {
        launch(.postDetailRefresh)
        XCTAssertTrue(post(1).waitForExistence(timeout: 5))
        post(1).tap()
        XCTAssertTrue(app.staticTexts["post-detail-title"].waitForExistence(timeout: 5))
        let article = app.scrollViews.firstMatch
        let start = article.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        let end = article.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertTrue(app.staticTexts["Обновлённая статья"].waitForExistence(timeout: 5))
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
        let detail = app.staticTexts["post-detail-title"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertEqual(detail.label, String(format: "Новость %03d", id))
        app.navigationBars["Публикация"].buttons.firstMatch.tap()
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertTrue(detail.waitForNonExistence(timeout: 5))
    }
}
