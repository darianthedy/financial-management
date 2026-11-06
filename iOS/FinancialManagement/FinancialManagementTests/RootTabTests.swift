import XCTest
@testable import FinancialManagement

/// The tab root's tabs and where it reopens (docs/ios-tab-root-plan.md).
final class RootTabTests: XCTestCase {
    func testTabsInOrder() {
        XCTAssertEqual(RootTab.allCases, [.dashboard, .accounts, .transactions, .budgets, .more])
        XCTAssertEqual(RootTab.allCases.compactMap(\.section), [.dashboard, .accounts, .transactions, .budgets])
    }

    /// Every screen is a tab or in More, once.
    func testMoreListsEveryOtherScreen() {
        XCTAssertEqual(AppSection.more, [.tags, .categories, .fixedExpenses, .scheduled, .settings])
        let tabs = RootTab.allCases.compactMap(\.section)
        XCTAssertEqual(Set(tabs + AppSection.more), Set(AppSection.allCases))
        XCTAssertTrue(Set(tabs).isDisjoint(with: AppSection.more))
    }

    /// Persisted in `@SceneStorage`: the tab keys match the former tabs'.
    func testRawValuesMatchTheFormerTabs() {
        XCTAssertEqual(RootTab(rawValue: "more"), .more)
        XCTAssertEqual(RootTab.dashboard.rawValue, "dashboard")
        XCTAssertEqual(AppSection(rawValue: "fixedExpenses"), .fixedExpenses)
    }

    func testReopensOnTheStoredTab() {
        XCTAssertEqual(RootRoute(storedTab: "budgets", storedMore: ""), RootRoute(tab: .budgets, morePath: []))
        XCTAssertEqual(RootRoute(storedTab: "more", storedMore: "tags"), RootRoute(tab: .more, morePath: [.tags]))
        XCTAssertEqual(RootRoute(storedTab: "more", storedMore: ""), RootRoute(tab: .more, morePath: []))
    }

    /// More's pushed screen only counts on More, and only a More screen.
    func testIgnoresAStrayMoreScreen() {
        XCTAssertEqual(RootRoute(storedTab: "accounts", storedMore: "tags"), RootRoute(tab: .accounts, morePath: []))
        XCTAssertEqual(RootRoute(storedTab: "more", storedMore: "accounts"), RootRoute(tab: .more, morePath: []))
    }

    /// Builds with the sections sidebar stored an `AppSection`: a management
    /// screen reopens in More, pushed.
    func testMigratesASidebarSection() {
        XCTAssertEqual(RootRoute(storedTab: "scheduled", storedMore: ""), RootRoute(tab: .more, morePath: [.scheduled]))
        XCTAssertEqual(RootRoute(storedTab: "settings", storedMore: ""), RootRoute(tab: .more, morePath: [.settings]))
    }

    func testUnknownFallsBackToTheDashboard() {
        XCTAssertEqual(RootRoute(storedTab: "nonsense", storedMore: "tags"), RootRoute(tab: .dashboard, morePath: []))
    }
}
