import XCTest
import SwiftUI
@testable import FinancialManagement

/// The tab sidebar floats over every tab root on regular width, as in Notes.
final class FloatingTabSidebarTests: XCTestCase {
    func testOnlyASidebarWideInsetFloats() {
        XCTAssertEqual(FloatingTabSidebar.width(leadingInset: 0, sizeClass: .regular), 0)
        XCTAssertEqual(FloatingTabSidebar.width(leadingInset: 44, sizeClass: .regular), 0)
        XCTAssertEqual(FloatingTabSidebar.width(leadingInset: 366, sizeClass: .regular), 366)
    }

    func testCompactWidthHasNoSidebar() {
        XCTAssertEqual(FloatingTabSidebar.width(leadingInset: 366, sizeClass: .compact), 0)
        XCTAssertEqual(FloatingTabSidebar.width(leadingInset: 366, sizeClass: nil), 0)
    }

    /// Laid out under the sidebar, the inner display keeps its full width, so
    /// a list → detail split still tiles with the sidebar open (585 pt beside
    /// it when flat would push).
    func testSplitStillTilesUnderTheSidebar() {
        XCTAssertFalse(SplitColumns.tiles(width: 585))
        XCTAssertTrue(SplitColumns.tiles(width: 585 + FloatingTabSidebar.width(leadingInset: 366, sizeClass: .regular)))
    }
}
