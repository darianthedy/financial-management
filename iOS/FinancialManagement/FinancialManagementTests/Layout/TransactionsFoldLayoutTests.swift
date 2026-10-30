import SwiftUI
import XCTest
@testable import FinancialManagement

/// A fold re-creates the Transactions tab root, so its filters and search live
/// in a model owned above the size-class branches.
@MainActor
final class TransactionsFoldLayoutTests: XCTestCase {
    private let row = "transactions.row.Top up Jenius"

    override func setUp() async throws {
        try XCTSkipUnless(FixtureMode.isEnabled, "Layout tests need DUO_FIXTURES=1.")
    }

    func testRecreatedListKeepsTheSharedModelsFilters() async throws {
        let appState = AppState()
        await appState.loadCurrencyData()
        let row = row
        let model = TransactionListViewModel()
        var filters = TransactionFilters()
        filters.dateFrom = "2020-01-01"
        filters.search = "Top up"
        model.applyFilters(filters)

        // Each render is a new view on the same model, as after a fold.
        for size in [LayoutSize.outerPortrait, .innerLandscape, .outerPortrait] {
            model.transactions = []
            _ = try await LayoutHarness.render(
                SplitRootContainer { TransactionListView(model: model, isTabRoot: true) }
                    .environment(\.transactionDrafts, TransactionEditorDrafts())
                    .environment(appState)
                    .environment(ThemeManager()),
                at: size,
                until: { $0[row] != nil }
            )
            XCTAssertEqual(model.filters, filters, "\(size)")
            XCTAssertFalse(model.transactions.isEmpty, "the view didn't load into the shared model at \(size)")
        }
    }
}
