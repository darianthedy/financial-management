import SwiftUI
import XCTest
@testable import FinancialManagement

/// D4.1: on regular width the Dashboard's cards reflow into two balanced
/// columns (status left, lists right) under a full-width Month Navigator;
/// compact keeps the single stack.
@MainActor
final class DashboardColumnsLayoutTests: XCTestCase {
    private let left = ["dashboard.verdict", "dashboard.cashflow", "dashboard.trend"]
    private let right = ["dashboard.accounts", "dashboard.planned", "dashboard.unplanned"]

    override func setUp() async throws {
        try XCTSkipUnless(FixtureMode.isEnabled, "Layout tests need DUO_FIXTURES=1.")
    }

    private func render(at size: LayoutSize) async throws -> LayoutSnapshot {
        let appState = AppState()
        await appState.loadCurrencyData()
        let all = left + right
        return try await LayoutHarness.render(
            NavigationStack { DashboardView() }
                .environment(appState)
                .environment(ThemeManager()),
            at: size,
            until: { frames in all.allSatisfy { frames[$0] != nil } }
        )
    }

    func testRegularTilesTwoColumns() async throws {
        for size in LayoutSize.all where size.horizontal == .regular {
            let snapshot = try await render(at: size)
            attach(snapshot, name: "dashboard-columns")
            let navigator = try snapshot.frame("dashboard.monthNavigator")
            let lefts = try left.map { try snapshot.frame($0) }
            let rights = try right.map { try snapshot.frame($0) }

            for (l, r) in zip(lefts, rights) {
                XCTAssertLessThanOrEqual(l.maxX, r.minX + 1, "left | right must tile at \(size)")
                XCTAssertEqual(l.width, r.width, accuracy: 1, "columns must be even at \(size)")
            }
            XCTAssertEqual(lefts[0].minY, rights[0].minY, accuracy: 1, "columns start together at \(size)")
            // Each column keeps its order, top-down.
            for column in [lefts, rights] {
                for (upper, lower) in zip(column, column.dropFirst()) {
                    XCTAssertLessThanOrEqual(upper.maxY, lower.minY + 1, "\(size)")
                }
            }
            // The Month Navigator spans both columns.
            XCTAssertLessThanOrEqual(navigator.minX, lefts[0].minX + 1, "\(size)")
            XCTAssertGreaterThanOrEqual(navigator.maxX, rights[0].maxX - 1, "\(size)")
            assertNoInteractiveOverlap(snapshot)
        }
    }

    func testCompactKeepsOneStack() async throws {
        for size in LayoutSize.all where size.horizontal == .compact {
            let snapshot = try await render(at: size)
            attach(snapshot, name: "dashboard-stack")
            let cards = try (left + right).map { try snapshot.frame($0) }
            for (upper, lower) in zip(cards, cards.dropFirst()) {
                XCTAssertLessThanOrEqual(upper.maxY, lower.minY + 1, "one stack in iPhone order at \(size)")
                XCTAssertEqual(upper.minX, lower.minX, accuracy: 1, "\(size)")
            }
            try assertCompactContentWidth(snapshot, probe: "dashboard.scroll")
            assertNoInteractiveOverlap(snapshot)
        }
    }
}
