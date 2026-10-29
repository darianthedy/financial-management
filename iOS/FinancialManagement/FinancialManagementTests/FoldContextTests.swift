import CoreGraphics
import XCTest
@testable import FinancialManagement

/// Region → `FoldContext` mapping (D0.2), with stubbed division frames.
final class FoldContextTests: XCTestCase {
    /// The inner display in landscape (book posture): 951 × 669 pt.
    private let inner = CGRect(x: 0, y: 0, width: 951, height: 669)

    func testNoRegionsIsNone() {
        XCTAssertEqual(FoldContext.from(divisionFrames: [], in: inner), .none)
    }

    func testVerticalDivisionIsBook() {
        let fold = CGRect(x: 470, y: 0, width: 11, height: 669)
        XCTAssertEqual(FoldContext.from(divisionFrames: [fold], in: inner), .book(divisionX: 475.5))
    }

    func testHorizontalDivisionIsTent() {
        let portrait = CGRect(x: 0, y: 0, width: 669, height: 951)
        let fold = CGRect(x: 0, y: 470, width: 669, height: 11)
        XCTAssertEqual(FoldContext.from(divisionFrames: [fold], in: portrait), .tent(divisionY: 475.5))
    }

    func testZeroThicknessDivisionStillCounts() {
        let fold = CGRect(x: 475, y: 0, width: 0, height: 669)
        XCTAssertEqual(FoldContext.from(divisionFrames: [fold], in: inner), .book(divisionX: 475))
    }

    func testDivisionOutsideTheViewIsIgnored() {
        // A detail column at x 400…951 when the fold sits at x 200 (in its
        // coordinates, the fold is off to the left).
        let column = CGRect(x: 0, y: 0, width: 551, height: 669)
        let fold = CGRect(x: -205, y: 0, width: 10, height: 669)
        XCTAssertEqual(FoldContext.from(divisionFrames: [fold], in: column), .none)
    }

    func testPositionIsRelativeToBounds() {
        let offset = CGRect(x: 100, y: 0, width: 851, height: 669)
        let fold = CGRect(x: 470, y: 0, width: 10, height: 669)
        XCTAssertEqual(FoldContext.from(divisionFrames: [fold], in: offset), .book(divisionX: 375))
    }

    func testLargestRegionWins() {
        let sliver = CGRect(x: 10, y: 0, width: 2, height: 20)
        let fold = CGRect(x: 470, y: 0, width: 10, height: 669)
        XCTAssertEqual(FoldContext.from(divisionFrames: [sliver, fold], in: inner), .book(divisionX: 475))
    }

    func testDivisionRect() {
        let size = CGSize(width: 951, height: 669)
        XCTAssertNil(FoldContext.none.divisionRect(in: size))
        XCTAssertEqual(
            FoldContext.book(divisionX: 475).divisionRect(in: size),
            CGRect(x: 475, y: 0, width: 0, height: 669)
        )
        XCTAssertEqual(
            FoldContext.tent(divisionY: 300).divisionRect(in: size),
            CGRect(x: 0, y: 300, width: 951, height: 0)
        )
    }

    // MARK: - Reflection fallback for ReservedRegion's frame

    /// Mirrors the shape the probe printed for SwiftUI's `ReservedRegion`.
    private struct StubSceneRegion {
        let frame: (Double, Double, Double, Double)
        let isActive: Bool
    }

    private struct StubRegion {
        let base: StubSceneRegion
    }

    func testReflectsFrameFromRegionDescription() {
        let region = StubRegion(base: .init(frame: (382, 0, 84, 174), isActive: true))
        XCTAssertEqual(
            ReservedRegionGeometry.globalFrame(of: region),
            CGRect(x: 382, y: 0, width: 84, height: 174)
        )
    }

    func testInactiveRegionHasNoFrame() {
        let region = StubRegion(base: .init(frame: (470, 0, 10, 669), isActive: false))
        XCTAssertNil(ReservedRegionGeometry.globalFrame(of: region))
    }

    func testUnknownShapeHasNoFrame() {
        XCTAssertNil(ReservedRegionGeometry.globalFrame(of: "not a region"))
    }
}
