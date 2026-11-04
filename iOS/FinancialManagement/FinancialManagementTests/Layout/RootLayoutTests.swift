import SwiftUI
import XCTest
@testable import FinancialManagement

/// The Notes-style root (design §3.1): one split on every display, opening on
/// the Dashboard with the sections out of the way. Screenshots feed gate G1.
@MainActor
final class RootLayoutTests: XCTestCase {
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

    func testOpensOnTheDashboard() async throws {
        for size in LayoutSize.all {
            let snapshot = try await renderRoot(at: size)
            attach(snapshot, name: "root")
            XCTAssertNotNil(snapshot.frames["dashboard.verdict"], "the Dashboard never showed at \(size)")
            // No tab bar any more: the sections are the split's sidebar.
            XCTAssertTrue(snapshot.tabTitles.isEmpty, "\(size): \(snapshot.tabTitles)")
            XCTAssertFalse(snapshot.labels.contains("More"), "More shown at \(size)")
            assertNoInteractiveOverlap(snapshot)
        }
    }
}
