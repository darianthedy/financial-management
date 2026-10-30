import XCTest
@testable import FinancialManagement

/// D5.1: the category swatches use an even column count.
final class SwatchGridLayoutTests: XCTestCase {
    func testCountIsAlwaysEven() {
        for width in stride(from: CGFloat(0), through: 1000, by: 7) {
            XCTAssertEqual(SwatchGridLayout.columns(width: width) % 2, 0, "width \(width)")
        }
    }

    func testSheetWidths() {
        XCTAssertEqual(SwatchGridLayout.columns(width: 0), 6)    // not measured yet
        XCTAssertEqual(SwatchGridLayout.columns(width: 340), 6)  // outer display
        XCTAssertEqual(SwatchGridLayout.columns(width: 358), 6)  // largest iPhone
        XCTAssertEqual(SwatchGridLayout.columns(width: 468), 8)  // form card
    }
}
