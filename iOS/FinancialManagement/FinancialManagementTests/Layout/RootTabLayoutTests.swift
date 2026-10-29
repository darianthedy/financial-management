import SwiftUI
import XCTest
@testable import FinancialManagement

/// D1.2: the root shows 4 tabs + More on compact width, and promotes More's
/// destinations (no More tab) on regular width. Screenshots feed gate G1.
@MainActor
final class RootTabLayoutTests: XCTestCase {
    private let primary: Set<String> = ["Dashboard", "Accounts", "Transactions", "Budgets"]

    override func setUp() async throws {
        try XCTSkipUnless(FixtureMode.isEnabled, "Layout tests need DUO_FIXTURES=1.")
    }

    private func renderRoot(at size: LayoutSize) async throws -> LayoutSnapshot {
        let appState = AppState()
        await appState.loadCurrencyData()
        return try await LayoutHarness.render(
            ContentRootView()
                .environment(appState)
                .environment(ThemeManager()),
            at: size,
            until: { $0["dashboard.verdict"] != nil }
        )
    }

    func testCompactShowsFourTabsPlusMore() async throws {
        for size in LayoutSize.all where size.horizontal == .compact {
            let snapshot = try await renderRoot(at: size)
            attach(snapshot, name: "root")

            XCTAssertTrue(primary.union(["More"]).isSubset(of: snapshot.labels), "\(size): \(snapshot.labels.sorted())")
            // Sidebar-only tabs must not leak into the compact tab bar
            // (the probe's §1.3 #5 failure). "Fixed Expenses" is also a
            // Dashboard card title, so it isn't checked here.
            for sidebarOnly in ["Categories", "Scheduled", "Settings"] {
                XCTAssertFalse(snapshot.labels.contains(sidebarOnly), "\(sidebarOnly) shown at \(size)")
            }
            assertNoInteractiveOverlap(snapshot)
        }
    }

    func testRegularPromotesMoreDestinations() async throws {
        for size in LayoutSize.all where size.horizontal == .regular {
            let snapshot = try await renderRoot(at: size)
            attach(snapshot, name: "root")

            XCTAssertTrue(primary.isSubset(of: snapshot.labels), "\(size): \(snapshot.labels.sorted())")
            XCTAssertFalse(snapshot.labels.contains("More"), "More tab shown at \(size)")
            XCTAssertTrue(snapshot.labels.contains("Settings"), "Settings tab missing at \(size)")
            assertNoInteractiveOverlap(snapshot)
        }
    }
}
