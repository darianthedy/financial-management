import XCTest
@testable import FinancialManagement

/// D4.1: the Dashboard's column count follows the proposed width.
@MainActor
final class DashboardColumnsTests: XCTestCase {
    private func count(_ width: CGFloat) -> Int {
        DashboardColumns.columnCount(width: width, spacing: 16, minimumColumnWidth: 300)
    }

    func testDuoWidths() {
        // Inner display, less the screen's 16 pt margins.
        XCTAssertEqual(count(951 - 32), 2)
        XCTAssertEqual(count(669 - 32), 2)
        // Half-width Split View and the outer display.
        XCTAssertEqual(count(475 - 32), 1)
        XCTAssertEqual(count(382 - 32), 1)
    }

    func testTwoColumnsOnlyWhenBothFit() {
        XCTAssertEqual(count(616), 2)
        XCTAssertEqual(count(615.5), 1)
    }
}
