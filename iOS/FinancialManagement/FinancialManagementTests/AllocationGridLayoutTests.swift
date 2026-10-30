import XCTest
@testable import FinancialManagement

/// D4.2: the installment allocation grid goes two-up on wide sheets.
@MainActor
final class AllocationGridLayoutTests: XCTestCase {
    func testColumnsFollowTheSheetWidth() {
        XCTAssertEqual(AllocationGridLayout.columns(formWidth: 0), 1)      // not measured yet
        XCTAssertEqual(AllocationGridLayout.columns(formWidth: 382), 1)    // outer display
        XCTAssertEqual(AllocationGridLayout.columns(formWidth: 540), 2)    // form-sized sheet
        XCTAssertEqual(AllocationGridLayout.columns(formWidth: 519), 1)
    }

    func testRowsKeepMonthOrder() {
        let months = ["2026-10", "2026-11", "2026-12"]
        XCTAssertEqual(AllocationGridLayout.rows(months, columns: 1), [["2026-10"], ["2026-11"], ["2026-12"]])
        XCTAssertEqual(AllocationGridLayout.rows(months, columns: 2), [["2026-10", "2026-11"], ["2026-12"]])
        XCTAssertEqual(AllocationGridLayout.rows([], columns: 2), [])
    }
}
