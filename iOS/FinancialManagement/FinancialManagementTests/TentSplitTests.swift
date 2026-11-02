import CoreGraphics
import XCTest
@testable import FinancialManagement

/// D6.2: `TentSplit`'s regions, each `margin` clear of the fold.
final class TentSplitTests: XCTestCase {
    private let size = CGSize(width: 669, height: 951)

    func testRegionsClearTheFold() throws {
        let regions = try XCTUnwrap(TentSplit.regions(in: size, foldY: 475, margin: 16))
        XCTAssertEqual(regions.glance, CGRect(x: 0, y: 0, width: 669, height: 459))
        XCTAssertEqual(regions.main, CGRect(x: 0, y: 491, width: 669, height: 460))
    }

    func testNoRegionsWithoutRoomOrAFold() {
        for foldY: CGFloat? in [nil, 10, 945] {
            XCTAssertNil(TentSplit.regions(in: size, foldY: foldY, margin: 16))
        }
    }
}
