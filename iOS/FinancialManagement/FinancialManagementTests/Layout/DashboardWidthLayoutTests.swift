import SwiftUI
import XCTest
@testable import FinancialManagement

/// D4.2: no Dashboard card header clips, down to a ⅓ Split View column.
@MainActor
final class DashboardWidthLayoutTests: XCTestCase {
    /// Split View at a third of the inner display's width (~317 pt), compact.
    private let splitThird = LayoutSize(
        name: "split-third", size: CGSize(width: 317, height: 669),
        horizontal: .compact, vertical: .regular, safeArea: .zero
    )
    private let header = "dashboardCard.header.Spending Trend"
    private let legend = "dashboard.trend.legend"

    override func setUp() async throws {
        try XCTSkipUnless(FixtureMode.isEnabled, "Layout tests need DUO_FIXTURES=1.")
    }

    func testTrendLegendNeverClips() async throws {
        let appState = AppState()
        await appState.loadCurrencyData()
        let (header, legend) = (header, legend)
        for size in LayoutSize.all + [splitThird] {
            let snapshot = try await LayoutHarness.render(
                NavigationStack { DashboardView() }
                    .environment(appState)
                    .environment(ThemeManager()),
                at: size,
                until: { $0[legend] != nil && $0[header] != nil }
            )
            attach(snapshot, name: "dashboard-widths")
            let headerFrame = try snapshot.frame(header)
            let legendFrame = try snapshot.frame(legend)
            XCTAssertGreaterThanOrEqual(legendFrame.minX, headerFrame.minX - 0.5, "\(size)")
            XCTAssertLessThanOrEqual(legendFrame.maxX, headerFrame.maxX + 0.5, "legend clips at \(size)")
            XCTAssertLessThanOrEqual(headerFrame.maxX, size.size.width - size.safeArea.right + 0.5, "header runs off screen at \(size)")
        }
    }
}
