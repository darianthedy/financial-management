import XCTest
@testable import FinancialManagement

/// D4.1: the Dashboard's column count follows the proposed width.
@MainActor
final class DashboardColumnsTests: XCTestCase {
    private func count(_ width: CGFloat) -> Int {
        DashboardColumns.columnCount(width: width, spacing: 16, minimumColumnWidth: DashboardColumns.defaultMinimumColumnWidth)
    }

    func testDuoWidths() {
        // Inner display, less the screen's 16 pt margins: landscape tiles,
        // portrait stacks so the list cards' names aren't truncated (DR 04).
        XCTAssertEqual(count(951 - 32), 2)
        XCTAssertEqual(count(669 - 32), 1)
        // Half-width Split View and the outer display.
        XCTAssertEqual(count(475 - 32), 1)
        XCTAssertEqual(count(382 - 32), 1)
    }

    func testTwoColumnsOnlyWhenBothFit() {
        XCTAssertEqual(count(676), 2)
        XCTAssertEqual(count(675.5), 1)
    }

    func testGutterSitsOnTheFold() throws {
        let widths = try XCTUnwrap(DashboardColumns.foldedWidths(
            width: 919, foldX: 459, gutter: 32, minimumColumnWidth: DashboardColumns.defaultMinimumColumnWidth
        ))
        XCTAssertEqual(widths.left, 443)
        XCTAssertEqual(widths.right, 444)
    }

    func testFoldThatStarvesAColumnKeepsEvenColumns() {
        for foldX: CGFloat? in [nil, 200, 700] {
            XCTAssertNil(DashboardColumns.foldedWidths(
                width: 919, foldX: foldX, gutter: 32, minimumColumnWidth: DashboardColumns.defaultMinimumColumnWidth
            ))
        }
    }
}
