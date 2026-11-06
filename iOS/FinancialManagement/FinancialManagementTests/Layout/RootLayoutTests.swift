import SwiftUI
import XCTest
@testable import FinancialManagement

/// The tab root (docs/ios-tab-root-plan.md): opens on the Dashboard tab on
/// every display. Screenshots feed gate G1. The tab bar itself is checked by
/// the XCUITests, which query it through the accessibility API.
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
            assertNoInteractiveOverlap(snapshot)
        }
    }
}
