import SwiftUI
import XCTest
@testable import FinancialManagement

/// D0.3 smoke test: today's `DashboardView`, rendered with fixture data at all
/// four standard sizes, with screenshots attached. Later layout tests follow
/// this shape: render → assert on probed frames → attach.
@MainActor
final class LayoutHarnessSmokeTests: XCTestCase {
    override func setUp() async throws {
        try XCTSkipUnless(
            FixtureMode.isEnabled,
            "Layout tests need DUO_FIXTURES=1 (the FinancialManagement scheme's Test action sets it)."
        )
    }

    func testFixtureBackendServesFilteredRows() async throws {
        let repo = DashboardRepository()
        let data = try await repo.load(yearMonth: FixtureStore.thisMonth)
        XCTAssertEqual(data.accounts.count, 4)
        XCTAssertEqual(data.budgets.count, 3)
        XCTAssertEqual(data.fixedExpenses.count, 3)
        // Rent and Internet have linked transactions; Phone Plan doesn't.
        XCTAssertEqual(data.paidFixedExpenseTotals.count, 2)
        XCTAssertEqual(data.trend.count, 6)
        // Unplanned = confirmed expenses with neither budget nor fixed expense.
        XCTAssertFalse(data.unplanned.isEmpty)
        XCTAssertTrue(data.unplanned.contains { $0.categoryName == "Uncategorized" })
    }

    func testFixtureSessionSignsIn() async throws {
        let session = try await SupabaseService.shared.client.auth.session
        XCTAssertEqual(session.user.id.uuidString.lowercased(), FixtureStore.userId)
    }

    func testDashboardRendersAtEveryDuoSize() async throws {
        let appState = AppState()
        await appState.loadCurrencyData()
        XCTAssertEqual(appState.defaultCurrency, "IDR")

        for size in LayoutSize.all {
            let snapshot = try await LayoutHarness.render(
                NavigationStack { DashboardView() }
                    .environment(appState)
                    .environment(ThemeManager()),
                at: size,
                until: { $0["dashboard.verdict"] != nil }
            )
            attach(snapshot, name: "dashboard")

            XCTAssertNotNil(snapshot.frames["dashboard.verdict"], "Dashboard data never loaded at \(size)")
            assertNoInteractiveOverlap(snapshot)
            try assertCompactContentWidth(snapshot, probe: "dashboard.scroll")
        }
    }

    /// The fold assertion trips when an interactive control crosses the fold.
    func testFoldOverlapIsDetected() async throws {
        let snapshot = try await LayoutHarness.render(
            Button("Wide") {}
                .frame(maxWidth: .infinity)
                .layoutProbe("wide", interactive: true),
            at: .innerLandscape,
            fold: .book(divisionX: 475)
        )
        XCTExpectFailure("A full-width button must overlap a book fold") {
            assertNoInteractiveOverlap(snapshot)
        }
    }
}
