import SwiftUI
import XCTest
@testable import FinancialManagement

/// D2.3: the tag grid's column count is always even on regular width.
final class TagGridColumnsTests: XCTestCase {
    func testCountIsEvenAndAtLeastTwo() {
        for width in stride(from: CGFloat(0), through: 1400, by: 7) {
            let count = TagGridColumns.count(width: width)
            XCTAssertGreaterThanOrEqual(count, 2, "width \(width)")
            XCTAssertEqual(count % 2, 0, "width \(width) gives \(count) columns")
        }
    }

    func testDuoWidths() {
        XCTAssertEqual(TagGridColumns.count(width: 360), 2)  // tiled list column
        XCTAssertEqual(TagGridColumns.count(width: 669), 4)  // inner portrait, full width
        XCTAssertEqual(TagGridColumns.count(width: 951), 4)  // inner landscape: 5.9 → 4, not 5
        XCTAssertEqual(TagGridColumns.count(width: 1280), 8)
    }

    func testCompactKeepsTheAdaptiveGrid() {
        XCTAssertEqual(TagGridColumns.items(width: 382, sizeClass: .compact).count, 1)
        XCTAssertEqual(TagGridColumns.items(width: 382, sizeClass: nil).count, 1)
        XCTAssertEqual(TagGridColumns.items(width: 951, sizeClass: .regular).count, 4)
    }
}
