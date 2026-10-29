import SwiftUI
import XCTest
@testable import FinancialManagement

/// D2.2: Categories pushes on compact (unchanged) and tiles its filtered
/// transactions on regular width.
@MainActor
final class CategoriesSplitLayoutTests: XCTestCase {
    private let row = "categories.row.Food & Drinks"

    override func setUp() async throws {
        try XCTSkipUnless(FixtureMode.isEnabled, "Layout tests need DUO_FIXTURES=1.")
    }

    private func render(_ view: CategoryListView, at size: LayoutSize, detail: Bool) async throws -> LayoutSnapshot {
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
            let snapshot = try await render(CategoryListView(), at: size, detail: false)
            attach(snapshot, name: "categories")
            try assertSplitListOnly(snapshot, rowProbe: row, placeholder: "Select a Category")
        }
    }

    func testRegularTilesTheCategorysTransactions() async throws {
        let food = try XCTUnwrap(try await CategoryRepository().list().first { $0.name == "Food & Drinks" })
        for size in LayoutSize.all where size.horizontal == .regular {
            let snapshot = try await render(CategoryListView(selectedCategory: food), at: size, detail: true)
            attach(snapshot, name: "categories-detail")
            try assertSplitTiled(snapshot)
            XCTAssertTrue(snapshot.labels.contains("Transactions"), "\(size): \(snapshot.labels.sorted())")
        }
    }
}
