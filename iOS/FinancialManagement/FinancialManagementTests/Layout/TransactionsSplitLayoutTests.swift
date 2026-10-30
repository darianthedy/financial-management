import SwiftUI
import XCTest
@testable import FinancialManagement

/// D3.1: Transactions keeps its compact list (edit in a sheet) and, as the tab
/// root on regular width, edits the selected transaction in the detail column.
@MainActor
final class TransactionsSplitLayoutTests: XCTestCase {
    private let row = "transactions.row.Top up Jenius"
    /// FixtureStore's newest transaction, "Top up Jenius" (first row on screen).
    private let topUp = UUID(uuidString: "0000f1c7-0006-4000-8000-00000000000c")!

    override func setUp() async throws {
        try XCTSkipUnless(FixtureMode.isEnabled, "Layout tests need DUO_FIXTURES=1.")
    }

    private func render(
        selected: UUID? = nil, drafts: TransactionEditorDrafts = TransactionEditorDrafts(),
        showsSummary: Bool = false, at size: LayoutSize
    ) async throws -> LayoutSnapshot {
        let appState = AppState()
        await appState.loadCurrencyData()
        let row = row
        return try await LayoutHarness.render(
            SplitRootContainer { TransactionListView(isTabRoot: true, selectedTransactionId: selected, showsSummary: showsSummary) }
                .environment(\.transactionDrafts, drafts)
                .environment(appState)
                .environment(ThemeManager()),
            at: size,
            until: {
                $0[row] != nil && (selected == nil || $0["split.detail"] != nil)
                    && (!showsSummary || $0["transactions.summary"] != nil)
            }
        )
    }

    func testListWithNothingSelected() async throws {
        for size in LayoutSize.all {
            let snapshot = try await render(at: size)
            attach(snapshot, name: "transactions")
            try assertSplitListOnly(snapshot, rowProbe: row, placeholder: "Select a Transaction")
        }
    }

    func testRegularEditsTheTransactionInTheDetailColumn() async throws {
        for size in LayoutSize.all where size.horizontal == .regular {
            let snapshot = try await render(selected: topUp, at: size)
            attach(snapshot, name: "transactions-detail")
            try assertSplitTiled(snapshot)
        }
    }

    /// Unfold → edit → fold: the compact push re-opens the same draft.
    func testDirtyDetailIsKeptAcrossAFold() async throws {
        let drafts = TransactionEditorDrafts()
        let tiled = try await render(selected: topUp, drafts: drafts, at: .innerLandscape)
        try assertSplitTiled(tiled)
        let model = try XCTUnwrap(drafts.transaction(withId: topUp).map {
            drafts.model(for: $0, currency: "IDR", decimalPlaces: 0)
        })
        model.description = "Top up (October)"

        let folded = try await render(selected: topUp, drafts: drafts, at: .outerPortrait)
        attach(folded, name: "transactions-folded")
        XCTAssertNotNil(folded.frames["split.detail"], "the draft wasn't pushed on compact")
        XCTAssertNil(folded.frames["split.list"])
        let kept = try XCTUnwrap(drafts.transaction(withId: topUp).map {
            drafts.model(for: $0, currency: "IDR", decimalPlaces: 0)
        })
        XCTAssertTrue(kept === model)
        XCTAssertEqual(kept.description, "Top up (October)")
        XCTAssertTrue(kept.hasChanges)
    }

    /// D3.2: on the inner display in landscape, Summary is a trailing
    /// inspector column beside list | detail, which keep their room.
    func testSummaryIsATrailingInspectorInLandscape() async throws {
        let snapshot = try await render(selected: topUp, showsSummary: true, at: .innerLandscape)
        attach(snapshot, name: "transactions-summary")
        let list = try snapshot.frame("split.list")
        let detail = try snapshot.frame("split.detail")
        let summary = try snapshot.frame("transactions.summary")
        XCTAssertLessThanOrEqual(list.maxX, detail.minX + 1)
        XCTAssertLessThanOrEqual(detail.maxX, summary.minX + 1, "the inspector must trail the detail")
        XCTAssertGreaterThanOrEqual(list.width, 299.5)
        XCTAssertGreaterThanOrEqual(detail.width, 280, "the detail column was squeezed")
        XCTAssertGreaterThanOrEqual(summary.width, SummaryPresentation.inspectorWidth.min - 0.5)
        assertNoInteractiveOverlap(snapshot)
    }
}
