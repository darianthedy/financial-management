import XCTest
@testable import FinancialManagement

/// The pending scheduled row's actions sit side by side only when they fit.
final class PendingActionsLayoutTests: XCTestCase {
    func testSideBySideWhereTheyFit() {
        XCTAssertTrue(PendingActionsLayout.fitsSideBySide(width: 380, needed: 360))
        XCTAssertTrue(PendingActionsLayout.fitsSideBySide(width: 0, needed: 360))   // not measured yet
        XCTAssertTrue(PendingActionsLayout.fitsSideBySide(width: 300, needed: 0))
    }

    /// Device tests: the 300 pt list column showed "C / E / D" (build 143), and
    /// the outer display "Confi… / Dis…" (build 144).
    func testStackedWhenTheyWouldTruncate() {
        XCTAssertFalse(PendingActionsLayout.fitsSideBySide(width: 268, needed: 360))
        XCTAssertFalse(PendingActionsLayout.fitsSideBySide(width: 316, needed: 360))
    }
}
