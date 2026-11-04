import SwiftUI
import UIKit
import XCTest
@testable import FinancialManagement

/// The Notes-style root's sections and column rules (design §3.1).
final class RootColumnsTests: XCTestCase {
    func testSectionsInSidebarOrder() {
        XCTAssertEqual(
            AppSection.primary + AppSection.management,
            [.dashboard, .accounts, .transactions, .budgets, .tags, .categories, .fixedExpenses, .scheduled, .settings]
        )
        XCTAssertEqual(Set(AppSection.primary + AppSection.management), Set(AppSection.allCases))
    }

    /// Persisted in `@SceneStorage` under the former tabs' key and values.
    func testRawValuesMatchTheFormerTabs() {
        XCTAssertEqual(AppSection(rawValue: "fixedExpenses"), .fixedExpenses)
        XCTAssertEqual(AppSection.dashboard.rawValue, "dashboard")
        XCTAssertNil(AppSection(rawValue: "more"))
    }

    func testOnlyDashboardAndSettingsHaveNoList() {
        XCTAssertEqual(AppSection.allCases.filter { !$0.hasList }, [.dashboard, .settings])
    }

    func testVisibility() {
        // A list section: the list beside the detail in landscape, always.
        XCTAssertEqual(RootColumns.visibility(hasList: true, selected: false, sideBySide: true), .doubleColumn)
        XCTAssertEqual(RootColumns.visibility(hasList: true, selected: true, sideBySide: true), .doubleColumn)
        // Portrait: the list over the detail until something is picked.
        XCTAssertEqual(RootColumns.visibility(hasList: true, selected: false, sideBySide: false), .doubleColumn)
        XCTAssertEqual(RootColumns.visibility(hasList: true, selected: true, sideBySide: false), .detailOnly)
        // Dashboard and Settings: their screen alone.
        for sideBySide in [true, false] {
            XCTAssertEqual(RootColumns.visibility(hasList: false, selected: false, sideBySide: sideBySide), .detailOnly)
        }
    }

    func testCompactOpensOnTheSectionsScreen() {
        XCTAssertEqual(RootColumns.compactColumn(for: .accounts), .content)
        XCTAssertEqual(RootColumns.compactColumn(for: .dashboard), .detail)
        XCTAssertEqual(RootColumns.compactColumn(for: .settings), .detail)
    }

    /// As in Notes: the sections push the list aside in landscape and slide
    /// over everything in portrait.
    func testSplitBehavior() {
        XCTAssertEqual(RootColumns.behavior(regular: true, sideBySide: true, hasList: true), .displace)
        XCTAssertEqual(RootColumns.behavior(regular: true, sideBySide: false, hasList: true), .overlay)
        // Dashboard and Settings: `.prominentDetail` overlays them instead.
        XCTAssertNil(RootColumns.behavior(regular: true, sideBySide: true, hasList: false))
        XCTAssertNil(RootColumns.behavior(regular: true, sideBySide: false, hasList: false))
        XCTAssertNil(RootColumns.behavior(regular: false, sideBySide: true, hasList: true))
    }
}
