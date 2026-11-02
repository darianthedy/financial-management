import SwiftUI
import XCTest
@testable import FinancialManagement

/// D6.2: in tent posture, read-only glance content sits above an injected fold
/// and the controls and list below it.
@MainActor
final class TentPostureLayoutTests: XCTestCase {
    private let foldY: CGFloat = 475
    private var tent: FoldContext { .tent(divisionY: foldY) }

    override func setUp() async throws {
        try XCTSkipUnless(FixtureMode.isEnabled, "Layout tests need DUO_FIXTURES=1.")
    }

    private func render(
        _ view: some View, fold: FoldContext, at size: LayoutSize = .innerPortrait, probe: String
    ) async throws -> LayoutSnapshot {
        let appState = AppState()
        await appState.loadCurrencyData()
        return try await LayoutHarness.render(
            view.environment(appState).environment(ThemeManager()),
            at: size, fold: fold,
            until: { $0[probe] != nil }
        )
    }

    private func assertSplit(
        _ snapshot: LayoutSnapshot, below probe: String,
        file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let glance = try snapshot.frame("tent.glance", file: file, line: line)
        XCTAssertLessThanOrEqual(glance.maxY, foldY, "glance crosses the fold", file: file, line: line)
        let main = try snapshot.frame(probe, file: file, line: line)
        XCTAssertGreaterThanOrEqual(main.minY, foldY, "'\(probe)' is above the fold", file: file, line: line)
        assertNoInteractiveOverlap(snapshot, file: file, line: line)
    }

    func testDashboardGlanceDropsItsCardsFromTheList() async throws {
        let view = NavigationStack { DashboardView() }
        let snapshot = try await render(view, fold: tent, probe: "dashboard.accounts")
        attach(snapshot, name: "dashboard-tent")
        try assertSplit(snapshot, below: "dashboard.monthNavigator")
        for id in ["dashboard.verdict", "dashboard.cashflow"] {
            XCTAssertLessThanOrEqual(try snapshot.frame(id).minY, foldY, "\(id) stays in the glance")
        }
        XCTAssertGreaterThanOrEqual(try snapshot.frame("dashboard.trend").minY, foldY)
    }

    func testBudgets() async throws {
        let card = "budgets.card.Groceries"
        let snapshot = try await render(SplitRootContainer { BudgetListView() }, fold: tent, probe: card)
        attach(snapshot, name: "budgets-tent")
        try assertSplit(snapshot, below: card)
    }

    func testFixedExpenses() async throws {
        // Unpaid, so it heads the list: Paid rows are below the shorter region.
        let row = "fixed.row.Phone Plan"
        let snapshot = try await render(SplitRootContainer { FixedExpenseListView() }, fold: tent, probe: row)
        attach(snapshot, name: "fixed-expenses-tent")
        try assertSplit(snapshot, below: row)
    }

    func testTransactions() async throws {
        let snapshot = try await render(
            SplitRootContainer { TransactionListView(isTabRoot: true) },
            fold: tent, probe: "transactions.list"
        )
        attach(snapshot, name: "transactions-tent")
        try assertSplit(snapshot, below: "transactions.list")
    }

    func testNoGlanceWhenFlatOrInBook() async throws {
        for fold in [FoldContext.none, .book(divisionX: 475)] {
            let snapshot = try await render(
                SplitRootContainer { BudgetListView() }, fold: fold,
                at: .innerLandscape, probe: "budgets.card.Groceries"
            )
            XCTAssertNil(snapshot.frames["tent.glance"], "\(fold)")
        }
    }

    func testCompactNeverSplits() async throws {
        let snapshot = try await render(
            SplitRootContainer { BudgetListView() }, fold: tent,
            at: .outerPortrait, probe: "budgets.card.Groceries"
        )
        XCTAssertNil(snapshot.frames["tent.glance"])
    }
}
