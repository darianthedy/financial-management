import SwiftUI
import XCTest
@testable import FinancialManagement

/// D2.4: Fixed Expenses keeps its compact list (no tap action) and, on
/// regular width, tiles the linked transactions with the month navigator in
/// the list column.
@MainActor
final class FixedExpensesSplitLayoutTests: XCTestCase {
    private let row = "fixed.row.Rent"

    override func setUp() async throws {
        try XCTSkipUnless(FixtureMode.isEnabled, "Layout tests need DUO_FIXTURES=1.")
    }

    private func render(_ view: FixedExpenseListView, at size: LayoutSize, detail: Bool) async throws -> LayoutSnapshot {
        let appState = AppState()
        await appState.loadCurrencyData()
        let row = row
        return try await LayoutHarness.render(
            SplitRootContainer { view }
                .environment(appState)
                .environment(ThemeManager()),
            at: size,
            until: { $0[row] != nil && (!detail || $0["split.detail"] != nil) }
        )
    }

    func testListWithNothingSelected() async throws {
        for size in LayoutSize.all {
            let snapshot = try await render(FixedExpenseListView(), at: size, detail: false)
            attach(snapshot, name: "fixed-expenses")
            try assertSplitListOnly(snapshot, rowProbe: row, placeholder: "Select a Fixed Expense")
        }
    }

    func testRegularTilesTheLinkedTransactions() async throws {
        let entries = try await FixedExpenseRepository().getForMonth(yearMonth: FixtureStore.thisMonth)
        let rent = try XCTUnwrap(entries.first { $0.name == "Rent" })
        for size in LayoutSize.all where size.horizontal == .regular {
            let snapshot = try await render(FixedExpenseListView(selectedExpenseId: rent.id), at: size, detail: true)
            attach(snapshot, name: "fixed-expenses-detail")
            try assertSplitTiled(snapshot)
        }
    }

    func testLinkedTransactionFiltersPinTheMonth() async throws {
        let entries = try await FixedExpenseRepository().getForMonth(yearMonth: FixtureStore.thisMonth)
        let expense = try XCTUnwrap(entries.first)
        let filters = FixedExpenseListView.linkedTransactionFilters(for: expense)
        XCTAssertEqual(filters.fixedExpenses?.values, [expense.name])
        let range = try XCTUnwrap(DateUtils.monthDateRange(expense.yearMonth))
        XCTAssertEqual(filters.dateFrom, range.start)
        XCTAssertEqual(filters.dateTo, range.end)
    }
}
