import SwiftUI
import XCTest
@testable import FinancialManagement

/// Tab ↔ size-class mapping (D1.1, design §3.1 continuity rule).
final class AppTabMappingTests: XCTestCase {
    func testVisibleTabs() {
        XCTAssertEqual(AppTab.visible(for: .compact), [.dashboard, .accounts, .transactions, .budgets, .more])
        XCTAssertEqual(AppTab.visible(for: nil), AppTab.visible(for: .compact))
        XCTAssertEqual(
            AppTab.visible(for: .regular),
            [.dashboard, .accounts, .transactions, .budgets, .tags, .categories, .fixedExpenses, .scheduled, .settings]
        )
        // Every tab is shown at exactly one of the two widths, or both for primary tabs.
        for tab in AppTab.allCases {
            XCTAssertTrue(tab.isVisible(for: .compact) || tab.isVisible(for: .regular), "\(tab) is never shown")
        }
    }

    func testPrimaryTabsNeverChange() {
        for tab in AppTab.primary {
            XCTAssertEqual(TabRoute(tab: tab).resolved(for: .compact), TabRoute(tab: tab))
            XCTAssertEqual(TabRoute(tab: tab).resolved(for: .regular), TabRoute(tab: tab))
        }
    }

    func testSidebarTabFoldsToMoreWithScreenPushed() {
        for destination in MoreDestination.allCases {
            XCTAssertEqual(
                TabRoute(tab: destination.tab).resolved(for: .compact),
                TabRoute(tab: .more, morePath: [destination]),
                "\(destination)"
            )
        }
        XCTAssertEqual(TabRoute(tab: .tags).resolved(for: nil), TabRoute(tab: .more, morePath: [.tags]))
    }

    func testMoreUnfoldsToPushedScreensTab() {
        for destination in MoreDestination.allCases {
            XCTAssertEqual(
                TabRoute(tab: .more, morePath: [destination]).resolved(for: .regular),
                TabRoute(tab: destination.tab),
                "\(destination)"
            )
        }
    }

    func testEmptyMoreUnfoldsToFirstManagementTab() {
        XCTAssertEqual(TabRoute(tab: .more).resolved(for: .regular), TabRoute(tab: .tags))
    }

    func testRoundTripsAreStable() {
        for tab in AppTab.allCases {
            let route = TabRoute(tab: tab)
            let compact = route.resolved(for: .compact)
            let regular = compact.resolved(for: .regular)
            XCTAssertTrue(compact.tab.isVisible(for: .compact), "\(tab) → \(compact)")
            XCTAssertTrue(regular.tab.isVisible(for: .regular), "\(tab) → \(regular)")
            // Resolving twice changes nothing.
            XCTAssertEqual(compact.resolved(for: .compact), compact)
            XCTAssertEqual(regular.resolved(for: .regular), regular)
            // A sidebar tab survives fold + unfold.
            if tab != .more { XCTAssertEqual(regular.tab, tab) }
        }
    }

    func testRawValuesAreStableForSceneStorage() {
        XCTAssertEqual(AppTab(rawValue: "fixedExpenses"), .fixedExpenses)
        XCTAssertEqual(AppTab.dashboard.rawValue, "dashboard")
    }
}
