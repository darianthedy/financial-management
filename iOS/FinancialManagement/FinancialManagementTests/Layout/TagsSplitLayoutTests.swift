import SwiftUI
import XCTest
@testable import FinancialManagement

/// D2.3: Tags pushes on compact (unchanged) and tiles its filtered
/// transactions on regular width, with an even column count in the grid.
@MainActor
final class TagsSplitLayoutTests: XCTestCase {
    private let card = "tags.card.Vacation"

    override func setUp() async throws {
        try XCTSkipUnless(FixtureMode.isEnabled, "Layout tests need DUO_FIXTURES=1.")
    }

    private func render(_ view: TagsListView, at size: LayoutSize, detail: Bool) async throws -> LayoutSnapshot {
        let appState = AppState()
        await appState.loadCurrencyData()
        let card = card
        return try await LayoutHarness.render(
            SplitRootContainer { view }
                .environment(appState)
                .environment(ThemeManager()),
            at: size,
            until: { $0[card] != nil && (!detail || $0["split.detail"] != nil) }
        )
    }

    func testGridWithNothingSelected() async throws {
        for size in LayoutSize.all {
            let snapshot = try await render(TagsListView(), at: size, detail: false)
            attach(snapshot, name: "tags")
            try assertSplitListOnly(snapshot, rowProbe: card, placeholder: "Select a Tag")

            if size.horizontal == .regular {
                // Even columns: the first row's cards split the column in two.
                let vacation = try snapshot.frame("tags.card.Vacation")
                let work = try snapshot.frame("tags.card.Work")
                XCTAssertEqual(vacation.minY, work.minY, accuracy: 1, "first two tags share a row at \(size)")
                let list = try snapshot.frame("split.list")
                XCTAssertLessThanOrEqual(work.maxX, list.maxX + 1, "\(size)")
            }
        }
    }

    func testRegularTilesTheTagsTransactions() async throws {
        let tags = try await TagRepository().list()
        let vacation = try XCTUnwrap(tags.first { $0.name == "Vacation" })
        for size in LayoutSize.all where size.horizontal == .regular {
            let snapshot = try await render(TagsListView(selectedTag: vacation), at: size, detail: true)
            attach(snapshot, name: "tags-detail")
            try assertSplitTiled(snapshot)
        }
    }
}
