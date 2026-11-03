import SwiftUI
import XCTest
@testable import FinancialManagement

/// D6.1: with an injected fold, nothing interactive sits on the division: the
/// Dashboard's gutter does, and Login and Splash keep to the regions.
@MainActor
final class BookPostureLayoutTests: XCTestCase {
    private let book = FoldContext.book(divisionX: 475)
    private let tent = FoldContext.tent(divisionY: 475)
    private let left = ["dashboard.verdict", "dashboard.cashflow", "dashboard.trend"]
    private let right = ["dashboard.accounts", "dashboard.planned", "dashboard.unplanned"]

    override func setUp() async throws {
        try XCTSkipUnless(FixtureMode.isEnabled, "Layout tests need DUO_FIXTURES=1.")
    }

    private func dashboard(fold: FoldContext) async throws -> LayoutSnapshot {
        let appState = AppState()
        await appState.loadCurrencyData()
        let all = left + right
        return try await LayoutHarness.render(
            NavigationStack { DashboardView() }
                .environment(appState)
                .environment(ThemeManager()),
            at: .innerLandscape, fold: fold,
            until: { frames in all.allSatisfy { frames[$0] != nil } }
        )
    }

    func testDashboardGutterSitsOnTheFold() async throws {
        let snapshot = try await dashboard(fold: book)
        attach(snapshot, name: "dashboard-book")
        for id in left { XCTAssertLessThanOrEqual(try snapshot.frame(id).maxX, 475 - 16 + 1, id) }
        for id in right { XCTAssertGreaterThanOrEqual(try snapshot.frame(id).minX, 475 + 16 - 1, id) }
        XCTAssertLessThanOrEqual(try snapshot.frame("dashboard.monthNavigator").maxX, 475)
        assertNoInteractiveOverlap(snapshot)
    }

    func testDashboardKeepsEvenColumnsWhenTheFoldStarvesOne() async throws {
        let snapshot = try await dashboard(fold: .book(divisionX: 200))
        XCTAssertEqual(
            try snapshot.frame(left[0]).width, try snapshot.frame(right[0]).width, accuracy: 1
        )
    }

    private func login(at size: LayoutSize, fold: FoldContext) async throws -> LayoutSnapshot {
        try await LayoutHarness.render(
            LoginView(), at: size, fold: fold,
            until: { $0["login.card"] != nil && $0["login.header"] != nil }
        )
    }

    func testLoginTakesOneRegionEachInBook() async throws {
        let snapshot = try await login(at: .innerLandscape, fold: book)
        attach(snapshot, name: "login-book")
        XCTAssertLessThanOrEqual(try snapshot.frame("login.header").maxX, 475)
        XCTAssertGreaterThanOrEqual(try snapshot.frame("login.card").minX, 475)
        assertNoInteractiveOverlap(snapshot)
    }

    func testLoginPutsTheCardBelowTheFoldInTent() async throws {
        let snapshot = try await login(at: .innerPortrait, fold: tent)
        attach(snapshot, name: "login-tent")
        XCTAssertLessThanOrEqual(try snapshot.frame("login.header").maxY, 475)
        XCTAssertGreaterThanOrEqual(try snapshot.frame("login.card").minY, 475)
        assertNoInteractiveOverlap(snapshot)
    }

    func testLoginKeepsOneColumnWhenFlat() async throws {
        let snapshot = try await login(at: .innerLandscape, fold: .none)
        let header = try snapshot.frame("login.header")
        let card = try snapshot.frame("login.card")
        XCTAssertEqual(card.width, 400, accuracy: 0.5)
        XCTAssertEqual(header.midX, card.midX, accuracy: 1)
        XCTAssertEqual(card.minY - header.maxY, 24, accuracy: 1)
        // Build 144: flat, the header touched the screen's top edge.
        XCTAssertGreaterThanOrEqual(header.minY, 16)
    }

    private func splash(fold: FoldContext, at size: LayoutSize) async throws -> CGRect {
        try await LayoutHarness.render(
            SplashView(), at: size, fold: fold, until: { $0["splash.content"] != nil }
        ).frame("splash.content")
    }

    func testSplashCentersInOneRegion() async throws {
        let flat = try await splash(fold: .none, at: .innerLandscape)
        let booked = try await splash(fold: book, at: .innerLandscape)
        XCTAssertGreaterThanOrEqual(booked.minX, 475, "trailing region")
        XCTAssertEqual(booked.midY, flat.midY, accuracy: 1, "stays vertically centered")

        let tented = try await splash(fold: tent, at: .innerPortrait)
        XCTAssertLessThanOrEqual(tented.maxY, 475, "top region")
    }

    /// A reader below the root measures the fold from its own origin, which is
    /// what lets the Dashboard work beside the sidebar.
    func testReaderReportsTheFoldInItsOwnCoordinates() async throws {
        let seen = FoldSpy()
        _ = try await LayoutHarness.render(
            HStack(spacing: 0) {
                Color.clear.frame(width: 300)
                FoldSpyView(spy: seen).readsFoldContext()
            },
            at: .innerLandscape, fold: book,
            until: { _ in seen.context != .none }
        )
        XCTAssertEqual(seen.context, .book(divisionX: 175))
    }
}

@MainActor
private final class FoldSpy {
    var context = FoldContext.none
}

private struct FoldSpyView: View {
    let spy: FoldSpy
    @Environment(\.foldContext) private var fold

    var body: some View {
        Color.clear.onChange(of: fold, initial: true) { spy.context = fold }
    }
}
