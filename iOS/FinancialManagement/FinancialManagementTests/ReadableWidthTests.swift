import XCTest
@testable import FinancialManagement

/// D5.2: readable margins come from the width, on regular width only.
final class ReadableWidthTests: XCTestCase {
    func testCompactKeepsTheSystemMargins() {
        XCTAssertNil(ReadableWidth.margin(width: 951, sizeClass: .compact))
        XCTAssertNil(ReadableWidth.margin(width: 951, sizeClass: nil))
    }

    func testNarrowRegularWidthKeepsTheSystemMargins() {
        XCTAssertNil(ReadableWidth.margin(width: 0, sizeClass: .regular))
        XCTAssertNil(ReadableWidth.margin(width: 560, sizeClass: .regular))
    }

    func testContentNeverExceedsTheMaximum() {
        for width in stride(from: CGFloat(561), through: 1400, by: 7) {
            let margin = try! XCTUnwrap(ReadableWidth.margin(width: width, sizeClass: .regular))
            XCTAssertLessThanOrEqual(width - 2 * margin, ReadableWidth.maximumContentWidth, "width \(width)")
        }
    }

    func testDuoWidths() {
        XCTAssertEqual(ReadableWidth.margin(width: 951, sizeClass: .regular), 196)
        XCTAssertEqual(ReadableWidth.margin(width: 669, sizeClass: .regular), 55)
    }

    /// Device test (build 143): Settings' sections slid under the sidebar,
    /// because one margin from the list's edges ignored the sidebar's inset.
    func testEachSideKeepsItsInset() throws {
        // Flat, sidebar open: 280 pt sidebar, 84 pt vertical bar.
        let margins = try XCTUnwrap(ReadableWidth.margins(
            width: 587, leadingInset: 280, trailingInset: 84, sizeClass: .regular
        ))
        XCTAssertEqual(margins.leading, 294)
        XCTAssertEqual(margins.trailing, 98)
        XCTAssertLessThanOrEqual(587 + 280 + 84 - margins.leading - margins.trailing, ReadableWidth.maximumContentWidth)
    }

    func testNarrowSafeAreaKeepsTheSystemMargins() {
        // Book posture, sidebar filling the leading region.
        XCTAssertNil(ReadableWidth.margins(width: 392, leadingInset: 475, trailingInset: 84, sizeClass: .regular))
        XCTAssertNil(ReadableWidth.margins(width: 867, leadingInset: 0, trailingInset: 84, sizeClass: .compact))
    }
}
