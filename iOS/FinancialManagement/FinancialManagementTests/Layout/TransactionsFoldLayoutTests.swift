import SwiftUI
import XCTest
@testable import FinancialManagement

/// A fold re-creates the Transactions tab root, so its filters and search live
/// in a model owned above the size-class branches.
@MainActor
final class TransactionsFoldLayoutTests: XCTestCase {
    @Observable
    final class Flip { var sizeClass: UserInterfaceSizeClass = .compact }

    struct Root: View {
        let flip: Flip
        let model: TransactionListViewModel

        var body: some View {
            SplitRootContainer { TransactionListView(model: model, isTabRoot: true, showsSummary: true) }
                .environment(\.horizontalSizeClass, flip.sizeClass)
        }
    }

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
        filters.dateFrom = Date(timeIntervalSince1970: 0)
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

    /// Flips the size class under a live view, which swaps its branch, the way
    /// a fold does: the Summary must still be open, and open only once.
    func testSummaryStaysOpenThroughAFold() async throws {
        let flip = Flip()
        let model = TransactionListViewModel()
        let appState = AppState()
        await appState.loadCurrencyData()

        let host = UIHostingController(
            rootView: Root(flip: flip, model: model)
                .environment(\.transactionDrafts, TransactionEditorDrafts())
                .environment(appState)
                .environment(ThemeManager())
        )
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        try await Task.sleep(for: .seconds(2))
        XCTAssertTrue(model.isShowingSummary)

        flip.sizeClass = .regular
        try await Task.sleep(for: .seconds(2))
        XCTAssertTrue(model.isShowingSummary, "the fold closed the Summary")

        flip.sizeClass = .compact
        try await Task.sleep(for: .seconds(2))
        XCTAssertTrue(model.isShowingSummary, "the fold closed the Summary")
    }
}
