import XCTest
@testable import FinancialManagement

/// D3.3: Add stays on the Duo's vertical bar; Summary overflows first. Hosted
/// renders can't see system toolbar items, so the rule is checked here and the
/// real 382 pt bar at gate G2.
@MainActor
final class TransactionsToolbarTests: XCTestCase {
    func testAddKeepsItsPlaceAndSummaryOverflowsFirst() {
        XCTAssertEqual(TransactionsToolbar.priority(of: .add), .high)
        XCTAssertEqual(TransactionsToolbar.priority(of: .summary), .low)
    }

    func testFromAndToShareARowOnlyOnWideSheets() {
        // The outer display's sheet (382 pt content, less the Form's insets).
        XCTAssertFalse(FilterDateRowLayout.isSideBySide(rowWidth: 340))
        // Not measured yet: today's layout.
        XCTAssertFalse(FilterDateRowLayout.isSideBySide(rowWidth: 0))
        // A page-sized sheet on the inner display.
        XCTAssertTrue(FilterDateRowLayout.isSideBySide(rowWidth: 620))
    }
}
