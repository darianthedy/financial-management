import SwiftUI
import XCTest
@testable import FinancialManagement

/// A fold re-creates Budgets and Fixed Expenses; their month lives in
/// `FoldKeptModels`, so it survives.
@MainActor
final class FoldKeptMonthLayoutTests: XCTestCase {
    override func setUp() async throws {
        try XCTSkipUnless(FixtureMode.isEnabled, "Layout tests need DUO_FIXTURES=1.")
    }

    private func recreate<V: View>(
        _ screen: V, models: FoldKeptModels, until loaded: @escaping () -> Bool
    ) async throws {
        let appState = AppState()
        await appState.loadCurrencyData()
        // Each render is a new view on the same models, as after a fold.
        for size in [LayoutSize.outerPortrait, .innerLandscape] {
            _ = try await LayoutHarness.render(
                SplitRootContainer { screen }
                    .environment(\.foldKeptModels, models)
                    .environment(appState)
                    .environment(ThemeManager()),
                at: size,
                until: { _ in loaded() }
            )
        }
    }

    func testBudgetsKeepTheirMonth() async throws {
        let models = FoldKeptModels()
        let month = DateUtils.navigate(DateUtils.currentYearMonth(), by: -1)
        models.budgets.yearMonth = month
        try await recreate(BudgetListView(), models: models) { !models.budgets.isLoading }
        XCTAssertEqual(models.budgets.yearMonth, month)
    }

    func testFixedExpensesKeepTheirMonth() async throws {
        let models = FoldKeptModels()
        let month = DateUtils.navigate(DateUtils.currentYearMonth(), by: -1)
        models.fixedExpenses.yearMonth = month
        try await recreate(FixedExpenseListView(), models: models) { !models.fixedExpenses.isLoading }
        XCTAssertEqual(models.fixedExpenses.yearMonth, month)
    }

    /// Proves the screens really use the kept models, not their local ones.
    func testScreensLoadIntoTheKeptModels() async throws {
        let models = FoldKeptModels()
        try await recreate(BudgetListView(), models: models) { !models.budgets.progress.isEmpty }
        XCTAssertFalse(models.budgets.progress.isEmpty)
    }
}
