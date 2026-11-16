import XCTest
@testable import PlatformDeck

final class DeckStoreTests: XCTestCase {
    var store: DeckStore!
    override func setUp() {
        let d = UserDefaults(suiteName: "test-\(UUID())")!
        store = DeckStore(defaults: d, bundle: Bundle(for: DeckStore.self))
    }
    func testLoadsAllCards() { XCTAssertGreaterThan(store.guides.count, 200); XCTAssertEqual(store.categories.count, 17) }
    func testEveryCategoryHasLabelAndCards() { for c in store.categories { XCTAssertFalse(store.guides(in: c).isEmpty); XCTAssertFalse(Categories.label(c).isEmpty) } }
    func testSearch() { XCTAssertFalse(store.search("dialog").isEmpty); XCTAssertEqual(store.search("").count, store.guides.count); XCTAssertTrue(store.search("zzzqqq").isEmpty) }
    func testFavoriteToggle() { let g = store.guides[0]; store.toggleFavorite(g); XCTAssertTrue(store.favorites.contains(g.id)); store.toggleFavorite(g); XCTAssertFalse(store.favorites.contains(g.id)) }
    func testLearnedProgress() { store.toggleLearned(store.guides[0]); XCTAssertEqual(store.progress, 1 / Double(store.guides.count), accuracy: 1e-9) }
    func testQuiz() { let q = store.makeQuiz(); XCTAssertEqual(q.count, 5); for x in q { XCTAssertEqual(x.options.count, 4); XCTAssertTrue(x.options.contains(x.answer)); XCTAssertEqual(Set(x.options.map(\.id)).count, 4) } }
    func testDailyPickStable() { let d = Date(); XCTAssertEqual(store.dailyPick(on: d), store.dailyPick(on: d)) }
    func testReset() { store.toggleFavorite(store.guides[1]); store.bestQuiz = 3; store.resetAll(); XCTAssertTrue(store.favorites.isEmpty); XCTAssertEqual(store.bestQuiz, 0) }
    func testUniqueIDs() { XCTAssertEqual(Set(store.guides.map(\.id)).count, store.guides.count) }
    func testSidebarRetapClearsSearch() {
        let nav = SidebarNav(selection: .today, query: "dialog")
        nav.select(.today)
        XCTAssertEqual(nav.selection, .today)
        XCTAssertEqual(nav.query, "")
        XCTAssertTrue(nav.path.isEmpty)
    }
    func testSidebarClickSwitchesSelectionAndClearsSearch() {
        let nav = SidebarNav(selection: .today, query: "css")
        nav.select(.category("css"))
        XCTAssertEqual(nav.selection, .category("css"))
        XCTAssertEqual(nav.query, "")
        XCTAssertTrue(nav.path.isEmpty)
    }
}
