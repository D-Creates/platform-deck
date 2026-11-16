import XCTest

final class PlatformDeckUITests: XCTestCase {
    var app: XCUIApplication!
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-resetData"]
        app.launch()
        app.activate()
    }

    func el(_ id: String) -> XCUIElement {
        #if os(macOS)
        for q in [app.buttons, app.staticTexts, app.cells, app.outlineRows] where q[id].firstMatch.exists { return q[id].firstMatch }
        #endif
        return app.descendants(matching: .any)[id].firstMatch
    }
    var guideRow: XCUIElement { app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'guide-'")).firstMatch }
    /// SwiftUI Text exposes its string as `value` on macOS and as `label` elsewhere.
    func text(_ e: XCUIElement) -> String {
        #if os(macOS)
        return e.value as? String ?? ""
        #else
        return e.label
        #endif
    }
    /// On macOS `tap()` synthesizes a touch (Touch Bar) event that never reaches a window, so a press there is a mouse click.
    func press(_ e: XCUIElement) {
        #if os(macOS)
        e.click()
        #else
        e.tap()
        #endif
    }
    #if os(macOS)
    func window(titled title: String) -> XCUIElement { app.windows.matching(NSPredicate(format: "title == %@", title)).firstMatch }
    /// Scrolls the column holding `e` until its centre is inside the window: down first, then back up past the start.
    func scrollIntoWindow(_ e: XCUIElement) {
        let window = app.windows.firstMatch
        var tries = 0
        while tries < 30, !window.frame.contains(CGPoint(x: e.frame.midX, y: e.frame.midY)) {
            let column = window.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: e.frame.midX - window.frame.minX, dy: window.frame.height / 2))
            column.scroll(byDeltaX: 0, deltaY: tries < 10 ? -150 : 150)
            tries += 1
        }
    }
    #endif
    func tapScrolling(_ id: String, _ file: StaticString = #filePath, _ line: UInt = #line) {
        let e = el(id)
        #if !os(macOS)
        for _ in 0..<20 {
            if e.exists && e.isHittable { break }
            app.swipeUp(velocity: .slow)
        }
        for _ in 0..<30 {
            if e.exists { break }
            app.swipeDown(velocity: .slow)
        }
        #endif
        if !e.waitForExistence(timeout: 5) { print("DUMPSTART"); print(app.debugDescription); print("DUMPEND") }
        XCTAssertTrue(e.exists, "missing \(id)", file: file, line: line)
        #if os(macOS)
        scrollIntoWindow(e)
        if e.isHittable { e.click() } else { e.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click() }
        #else
        e.tap()
        #endif
    }
    /// Leaves the pushed screen that shows `id`. On macOS the next step would pass from any screen, so the pop itself is checked there.
    func back(from id: String) {
        #if os(macOS)
        let toolbarBack = app.buttons["Back"].firstMatch
        if toolbarBack.waitForExistence(timeout: 2) && toolbarBack.isHittable {
            toolbarBack.click()
        } else {
            app.menuBars.menuBarItems["Deck"].click()
            app.menuBars.menuItems["Back"].click()
        }
        XCTAssertTrue(el(id).waitForNonExistence(timeout: 5), "still showing \(id) after Back")
        #else
        let backButton = app.navigationBars.buttons.matching(
            NSPredicate(format: "label != 'Hide Sidebar'")
        ).firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "missing navigation back button")
        backButton.tap()
        #endif
    }

    #if os(iOS)
    /// Selects a section by label: a tab-bar button on compact width, a sidebar row in the iPad split view.
    func tapTab(_ name: String, _ file: StaticString = #filePath, _ line: UInt = #line) {
        let tab = app.tabBars.buttons[name].firstMatch
        if tab.waitForExistence(timeout: 1.5) && tab.isHittable { tab.tap(); return }
        let sidebar = app.buttons["sidebar-\(name.lowercased())"].firstMatch
        if sidebar.exists && sidebar.isHittable { sidebar.tap(); return }
        let sidebarToggle = app.buttons.matching(
            NSPredicate(format: "identifier == 'ToggleSidebar' OR label CONTAINS[c] 'Show Sidebar' OR label CONTAINS[c] 'Toggle Sidebar'")
        ).firstMatch
        if sidebarToggle.exists && sidebarToggle.isHittable {
            sidebarToggle.tap()
        } else if app.navigationBars.buttons.firstMatch.exists && app.navigationBars.buttons.firstMatch.isHittable {
            app.navigationBars.buttons.firstMatch.tap()
        }
        if sidebar.waitForExistence(timeout: 3) && sidebar.isHittable {
            sidebar.tap()
            Thread.sleep(forTimeInterval: 0.35)
            if app.windows.firstMatch.frame.width < app.windows.firstMatch.frame.height, sidebar.isHittable {
                app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.14)).tap()
            }
            return
        }
        let label = app.buttons[name].firstMatch
        if label.waitForExistence(timeout: 3) { label.tap(); return }
        XCTFail("missing section \(name)", file: file, line: line)
    }
    #endif

    /// Full walk: daily pick → favorite/learned/share → quiz (5 answers) → categories → search → settings reset.
    func testEveryScreenAndButton() {
        // Daily pick and detail buttons
        tapScrolling("daily-pick")
        if !el("detail-title").waitForExistence(timeout: 5) { print("DUMPSTART"); print(app.debugDescription); print("DUMPEND") }
        XCTAssertTrue(el("detail-title").exists)
        tapScrolling("favorite-button"); tapScrolling("learned-button")
        #if !os(watchOS)
        XCTAssertTrue(el("share-button").exists)
        #endif
        back(from: "detail-title")
        // Progress reflects learned + favorite
        #if !os(watchOS)
        XCTAssertTrue(el("progress-text").waitForExistence(timeout: 5))
        XCTAssertTrue(text(el("progress-text")).hasPrefix("1 of"), text(el("progress-text")))
        #endif
        // Quiz: answer all 5
        tapScrolling("start-quiz-or-link")
        for _ in 0..<5 {
            tapScrolling("quiz-option-0")
            tapScrolling("quiz-next")
        }
        XCTAssertTrue(el("quiz-score").waitForExistence(timeout: 5))
        tapScrolling("quiz-again"); XCTAssertTrue(el("quiz-prompt").waitForExistence(timeout: 5))
        back(from: "quiz-prompt")
        // Browse every category
        #if os(iOS)
        tapTab("Browse")
        #endif
        #if os(watchOS)
        let cats = ["accessibility", "built-in-ai", "css"]
        #else
        let cats = ["accessibility", "css", "performance", "security"]
        #endif
        for c in cats {
            tapScrolling("category-\(c)")
            #if os(macOS)
            let name = text(el("category-\(c)"))
            XCTAssertTrue(window(titled: name).waitForExistence(timeout: 5), "detail pane did not switch to \(c) (\(name))")
            XCTAssertTrue(guideRow.waitForExistence(timeout: 5), "no cards listed for \(c)")
            #else
            XCTAssertTrue(app.cells.count > 0 || app.buttons.count > 2)
            back(from: "category-\(c)")
            #endif
        }
        // Search (not on watch)
        #if os(iOS) || os(macOS)
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5)); press(field); field.typeText("dialog")
        #if os(macOS)
        XCTAssertTrue(window(titled: "Search").waitForExistence(timeout: 5), "search results not shown")
        #endif
        XCTAssertTrue(guideRow.waitForExistence(timeout: 5))
        #endif
        // Favorites list shows the card
        #if os(iOS)
        if app.buttons["Close"].exists { app.buttons["Close"].tap() } else if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
        tapTab("Favorites")
        XCTAssertTrue(app.navigationBars["Favorites"].waitForExistence(timeout: 5))
        XCTAssertTrue(guideRow.waitForExistence(timeout: 5))
        tapTab("Settings")
        #elseif os(macOS)
        tapScrolling("sidebar-settings")
        #else
        tapScrolling("settings-link")
        #endif
        tapScrolling("reset-button")
        let confirm = app.buttons["Reset"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); press(confirm)
        #if !os(watchOS)
        #if os(macOS)
        let textKey = "value"
        #else
        let textKey = "label"
        #endif
        let zero = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'progress-text' AND %K BEGINSWITH '0 of'", textKey)).firstMatch
        if !zero.waitForExistence(timeout: 5) { print("PROGRESS:", text(el("progress-text"))) }
        XCTAssertTrue(zero.exists)
        #endif
        let about = el("about-version")
        #if os(watchOS)
        for _ in 0..<12 where !about.exists { app.swipeUp(velocity: .slow) }
        #endif
        XCTAssertTrue(about.waitForExistence(timeout: 5))
    }
}

#if os(iOS)
/// Attaches to an already-launched PlatformDeck instance (`simctl launch ... -resetData -seed`)
/// and navigates to each of the 5 feature screens without terminating the app on teardown,
/// allowing synchronous foreground `xcrun simctl io <id> screenshot` captures after each test.
final class PlatformDeckScreenshotUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: "fr.dcreations.platformdeck")
        app.activate()
    }

    private func el(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private var guideRow: XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'guide-'")).firstMatch
    }

    private func tapScrolling(_ id: String, _ file: StaticString = #filePath, _ line: UInt = #line) {
        let e = el(id)
        for _ in 0..<15 {
            if e.exists && e.isHittable { break }
            app.swipeUp(velocity: .slow)
        }
        for _ in 0..<20 {
            if e.exists && e.isHittable { break }
            app.swipeDown(velocity: .slow)
        }
        XCTAssertTrue(e.waitForExistence(timeout: 10), "missing \(id)", file: file, line: line)
        e.tap()
    }

    private func dismissFloatingSidebarIfNeeded(_ sidebarRow: XCUIElement) {
        Thread.sleep(forTimeInterval: 0.45)
        let win = app.windows.firstMatch
        if win.frame.width < win.frame.height, sidebarRow.exists && sidebarRow.isHittable {
            let hideBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Hide Sidebar'")).firstMatch
            if hideBtn.exists && hideBtn.isHittable {
                hideBtn.tap()
            } else {
                win.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.14)).tap()
            }
            Thread.sleep(forTimeInterval: 0.35)
        }
    }

    private func selectSection(_ name: String, _ file: StaticString = #filePath, _ line: UInt = #line) {
        let tab = app.tabBars.buttons[name].firstMatch
        if tab.waitForExistence(timeout: 1.5) && tab.isHittable {
            tab.tap()
            return
        }
        let sidebar = app.buttons["sidebar-\(name.lowercased())"].firstMatch
        if sidebar.exists && sidebar.isHittable {
            sidebar.tap()
            dismissFloatingSidebarIfNeeded(sidebar)
            return
        }
        let togglePred = NSPredicate(
            format: "identifier == 'ToggleSidebar' OR label CONTAINS[c] 'Show Sidebar' OR label CONTAINS[c] 'Toggle Sidebar' OR label == 'Deck'"
        )
        let toggle = app.buttons.matching(togglePred).firstMatch
        if toggle.exists && toggle.isHittable {
            toggle.tap()
        } else {
            // Pop pushed detail stack if needed so the root sidebar toggle button is exposed
            for _ in 0..<3 {
                if sidebar.exists && sidebar.isHittable { break }
                if toggle.exists && toggle.isHittable { toggle.tap(); break }
                let navBtn = app.navigationBars.buttons.firstMatch
                if navBtn.exists && navBtn.isHittable {
                    navBtn.tap()
                    Thread.sleep(forTimeInterval: 0.35)
                }
            }
            if !sidebar.isHittable, toggle.exists && toggle.isHittable {
                toggle.tap()
            } else if !sidebar.isHittable, app.navigationBars.buttons.firstMatch.exists {
                app.navigationBars.buttons.firstMatch.tap()
            }
        }
        if sidebar.waitForExistence(timeout: 8) && sidebar.isHittable {
            sidebar.tap()
            dismissFloatingSidebarIfNeeded(sidebar)
            return
        }
        XCTFail("missing section \(name)", file: file, line: line)
    }

    func test1Today() {
        XCTAssertTrue(el("daily-pick").waitForExistence(timeout: 20))
        XCTAssertTrue(el("progress-text").waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 0.6)
    }

    func test2Browse() {
        selectSection("Browse")
        XCTAssertTrue(el("category-accessibility").waitForExistence(timeout: 15))
        XCTAssertTrue(el("category-css").waitForExistence(timeout: 15))
        Thread.sleep(forTimeInterval: 0.6)
    }

    func test3Card() {
        if !el("category-css").exists {
            selectSection("Browse")
            XCTAssertTrue(el("category-css").waitForExistence(timeout: 15))
        }
        tapScrolling("category-css")
        XCTAssertTrue(el("guide-css-layout").waitForExistence(timeout: 15))
        tapScrolling("guide-css-layout")
        XCTAssertTrue(el("detail-title").waitForExistence(timeout: 15))
        let fav = el("favorite-button")
        if fav.waitForExistence(timeout: 10), fav.label == "Favorite" { fav.tap() }
        let learned = el("learned-button")
        if learned.waitForExistence(timeout: 10), learned.label == "Mark learned" { learned.tap() }
        Thread.sleep(forTimeInterval: 0.6)
    }

    func test4Quiz() {
        selectSection("Today")
        XCTAssertTrue(el("start-quiz-or-link").waitForExistence(timeout: 15))
        tapScrolling("start-quiz-or-link")
        XCTAssertTrue(el("quiz-prompt").waitForExistence(timeout: 15))
        XCTAssertTrue(el("quiz-option-0").waitForExistence(timeout: 15))
        el("quiz-option-0").tap()
        XCTAssertTrue(el("quiz-next").waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 0.6)
    }

    func test5Favorites() {
        selectSection("Favorites")
        XCTAssertTrue(app.navigationBars["Favorites"].waitForExistence(timeout: 15))
        XCTAssertTrue(guideRow.waitForExistence(timeout: 15))
        Thread.sleep(forTimeInterval: 0.6)
    }
}
#endif
