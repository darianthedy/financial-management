import SwiftUI
import XCTest
@testable import FinancialManagement

/// D2.6: Scheduled keeps its compact list (edit in a sheet) and, on regular
/// width, edits the selected schedule in the detail column.
@MainActor
final class ScheduledSplitLayoutTests: XCTestCase {
    private let row = "scheduled.row.Salary"
    /// FixtureStore's first schedule, "Salary".
    private let salary = UUID(uuidString: "0000f1c7-0007-4000-8000-000000000001")!

    override func setUp() async throws {
        try XCTSkipUnless(FixtureMode.isEnabled, "Layout tests need DUO_FIXTURES=1.")
    }

    private func render(_ view: ScheduledListView, at size: LayoutSize, detail: Bool) async throws -> LayoutSnapshot {
        let appState = AppState()
        await appState.loadCurrencyData()
        let row = row
        return try await LayoutHarness.render(
            SplitRootContainer { view }
                .environment(appState)
                .environment(ThemeManager()),
            at: size,
            until: { $0[row] != nil && (!detail || $0["split.detail"] != nil) }
        )
    }

    func testListWithNothingSelected() async throws {
        for size in LayoutSize.all {
            let snapshot = try await render(ScheduledListView(), at: size, detail: false)
            attach(snapshot, name: "scheduled")
            try assertSplitListOnly(snapshot, rowProbe: row, placeholder: "Select a Schedule")
        }
    }

    func testRegularEditsTheScheduleInTheDetailColumn() async throws {
        for size in LayoutSize.all where size.horizontal == .regular {
            let snapshot = try await render(ScheduledListView(selectedScheduleId: salary), at: size, detail: true)
            attach(snapshot, name: "scheduled-detail")
            try assertSplitTiled(snapshot)
            // The embedded form keeps its own Cancel / Save.
            XCTAssertTrue(snapshot.labels.contains("Save"), "\(size): \(snapshot.labels.sorted())")
            XCTAssertTrue(snapshot.labels.contains("Cancel"), "\(size)")
        }
    }
}
