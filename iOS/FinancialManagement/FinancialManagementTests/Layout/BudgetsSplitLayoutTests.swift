import SwiftUI
import XCTest
@testable import FinancialManagement

/// D2.5: Budgets drills down by push on compact (unchanged) and tiles the
/// drill-down on regular width; the selection is keyed by name and month.
@MainActor
final class BudgetsSplitLayoutTests: XCTestCase {
    private let card = "budgets.card.Groceries"

    override func setUp() async throws {
        try XCTSkipUnless(FixtureMode.isEnabled, "Layout tests need DUO_FIXTURES=1.")
    }

    private func render(_ view: BudgetListView, at size: LayoutSize, detail: Bool) async throws -> LayoutSnapshot {
        let appState = AppState()
        await appState.loadCurrencyData()
        let card = card
        return try await LayoutHarness.render(
            SplitRootContainer { view }
                .environment(appState)
                .environment(ThemeManager()),
            at: size,
            until: { $0[card] != nil && (!detail || $0["split.detail"] != nil) }
        )
    }

    func testCardsWithNothingSelected() async throws {
        for size in LayoutSize.all {
            let snapshot = try await render(BudgetListView(), at: size, detail: false)
            attach(snapshot, name: "budgets")
            try assertSplitListOnly(snapshot, rowProbe: card, placeholder: "Select a Budget")
            if size.horizontal == .regular {
                // BudgetCard's max width stretches to the column (design §S7).
                let list = try snapshot.frame("split.list")
                let groceries = try snapshot.frame(card)
                XCTAssertLessThanOrEqual(groceries.maxX, list.maxX + 1, "\(size)")
            }
        }
    }

    func testRegularTilesTheDrilldown() async throws {
        let groceries = BudgetDrilldown(name: "Groceries", yearMonth: FixtureStore.thisMonth)
        for size in LayoutSize.all where size.horizontal == .regular {
            let snapshot = try await render(BudgetListView(drilldown: groceries), at: size, detail: true)
            attach(snapshot, name: "budgets-detail")
            try assertSplitTiled(snapshot)
        }
    }

    func testDrilldownIsKeyedByNameAndMonth() {
        let a = BudgetDrilldown(name: "Groceries", yearMonth: "2026-10")
        XCTAssertEqual(a, BudgetDrilldown(name: "Groceries", yearMonth: "2026-10"))
        XCTAssertNotEqual(a, BudgetDrilldown(name: "Groceries", yearMonth: "2026-11"))
        XCTAssertNotEqual(a.id, BudgetDrilldown(name: "Groceries", yearMonth: "2026-11").id)
    }
}
