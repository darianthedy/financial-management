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
}
