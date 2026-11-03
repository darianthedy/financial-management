import XCTest
@testable import FinancialManagement

/// The pending scheduled row's actions sit side by side only when they fit.
final class PendingActionsLayoutTests: XCTestCase {
    func testSideBySideWhereTheyFit() {
        let needed = PendingActionsLayout.sideBySideWidth
        XCTAssertTrue(PendingActionsLayout.fitsSideBySide(width: 342, needed: needed))   // outer display row
        XCTAssertTrue(PendingActionsLayout.fitsSideBySide(width: 0, needed: needed))     // not measured yet
    }

    /// Device test (build 143): the 300 pt list column showed "C", "E", "D".
    func testStackedInTheDuoListColumn() {
        XCTAssertFalse(PendingActionsLayout.fitsSideBySide(width: 268, needed: PendingActionsLayout.sideBySideWidth))
    }

    func testLargerTextNeedsMoreRoom() {
        XCTAssertFalse(PendingActionsLayout.fitsSideBySide(width: 342, needed: PendingActionsLayout.sideBySideWidth * 1.3))
    }
}
