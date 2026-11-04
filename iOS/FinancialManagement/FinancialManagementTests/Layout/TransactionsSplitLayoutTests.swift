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
        selected: UUID? = nil, drafts: TransactionEditorDrafts? = nil,
        showsSummary: Bool = false, at size: LayoutSize
    ) async throws -> LayoutSnapshot {
        let appState = AppState()
        await appState.loadCurrencyData()
        let row = row
        let drafts = drafts ?? TransactionEditorDrafts()
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
        for size in LayoutSize.all where LayoutHarness.tilesSplit(size) {
            let snapshot = try await render(selected: topUp, at: size)
            attach(snapshot, name: "transactions-detail")
            try assertSplitTiled(snapshot)
        }
    }

    /// G2: the list fills its column, and its rows keep a readable title. The
    /// plain List's insets take about 32 pt of the row.
    func testRowsFillTheListColumn() async throws {
        for size in LayoutSize.all {
            guard try LayoutHarness.sceneFits(size) else { continue }
            let snapshot = try await render(at: size)
            let list = try snapshot.frame("transactions.list")
            let rowFrame = try snapshot.frame(row)
            XCTAssertGreaterThanOrEqual(
                rowFrame.width, list.width - 60,
                "row \(rowFrame) in list \(list) at \(size)"
            )
            if LayoutHarness.tilesSplit(size) {
                let column = try snapshot.frame("split.list")
                XCTAssertGreaterThanOrEqual(
                    list.width, column.width - 1, "list \(list) in column \(column) at \(size)"
                )
            }
            let title = try snapshot.frame("transactionRow.title.Top up Jenius")
            XCTAssertGreaterThanOrEqual(title.width, 60, "title \(title) in row \(rowFrame) at \(size)")
            // One line of money, inside the row: never wrapped or cut.
            let amount = try snapshot.frame("transactionRow.amount.Top up Jenius")
            XCTAssertLessThanOrEqual(amount.height, 30, "amount wrapped: \(amount) at \(size)")
            XCTAssertLessThanOrEqual(amount.maxX, rowFrame.maxX + 0.5, "amount \(amount) in row \(rowFrame) at \(size)")
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

    /// Summary is a sheet on regular width too: the split keeps its columns
    /// (a side panel inside the system split covered the editor).
    func testSummaryIsASheetThatLeavesTheSplitAlone() async throws {
        let size = LayoutSize.innerLandscape
        guard LayoutHarness.tilesSplit(size) else { return }
        let appState = try await loadedAppState()
        let snapshot = try await LayoutHarness.render(
            SplitRootContainer { TransactionListView(isTabRoot: true, selectedTransactionId: topUp, showsSummary: true) }
                .environment(\.transactionDrafts, TransactionEditorDrafts())
                .environment(appState)
                .environment(ThemeManager()),
            at: size,
            until: { $0["transactions.summary"] != nil && $0["split.detail"] != nil }
        )
        attach(snapshot, name: "transactions-summary")
        XCTAssertNotNil(snapshot.frames["transactions.summary"], "the Summary never rendered")
        try assertSplitTiled(snapshot)
    }

    private func loadedAppState() async throws -> AppState {
        let appState = AppState()
        await appState.loadCurrencyData()
        return appState
    }
}
