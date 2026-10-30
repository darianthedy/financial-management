import SwiftUI
import XCTest
@testable import FinancialManagement

/// D3.2: Summary is an inspector only where list | detail | inspector fit.
@MainActor
final class SummaryPresentationTests: XCTestCase {
    func testInnerLandscapeUsesTheInspector() {
        XCTAssertEqual(SummaryPresentation.style(isTabRoot: true, sizeClass: .regular, width: 951), .inspector)
    }

    func testInnerPortraitKeepsTheSheet() {
        XCTAssertEqual(SummaryPresentation.style(isTabRoot: true, sizeClass: .regular, width: 669), .sheet)
    }

    func testCompactKeepsTheSheet() {
        XCTAssertEqual(SummaryPresentation.style(isTabRoot: true, sizeClass: .compact, width: 466), .sheet)
        // Even when wide: compact is compact (e.g. the kill switch is off).
        XCTAssertEqual(SummaryPresentation.style(isTabRoot: true, sizeClass: .compact, width: 1200), .sheet)
    }

    func testDrillDownsKeepTheSheet() {
        XCTAssertEqual(SummaryPresentation.style(isTabRoot: false, sizeClass: .regular, width: 1200), .sheet)
    }

    func testThreshold() {
        let edge = SummaryPresentation.minimumInspectorScreenWidth
        XCTAssertEqual(SummaryPresentation.style(isTabRoot: true, sizeClass: .regular, width: edge), .inspector)
        XCTAssertEqual(SummaryPresentation.style(isTabRoot: true, sizeClass: .regular, width: edge - 1), .sheet)
    }
}
