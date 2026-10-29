import XCTest
@testable import FinancialManagement

/// Shared checks for Phase 2 list → detail screens (`.splitDetail`).
extension XCTestCase {
    /// Nothing selected: regular width tiles the list beside `placeholder`;
    /// compact shows only the list, at least 382 pt wide (`rowProbe`).
    func assertSplitListOnly(
        _ snapshot: LayoutSnapshot, rowProbe: String, placeholder: String,
        file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let size = snapshot.size
        XCTAssertNotNil(snapshot.frames[rowProbe], "'\(rowProbe)' never appeared at \(size)", file: file, line: line)
        XCTAssertNil(snapshot.frames["split.detail"], "detail shown with nothing selected at \(size)", file: file, line: line)
        if size.horizontal == .regular {
            let list = try snapshot.frame("split.list", file: file, line: line)
            let empty = try snapshot.frame("split.placeholder", file: file, line: line)
            XCTAssertLessThanOrEqual(list.maxX, empty.minX + 1, "list | placeholder must tile at \(size)", file: file, line: line)
            XCTAssertTrue(snapshot.labels.contains(placeholder), "'\(placeholder)' missing at \(size)", file: file, line: line)
        } else {
            XCTAssertNil(snapshot.frames["split.list"], "compact must not split at \(size)", file: file, line: line)
            try assertCompactContentWidth(snapshot, probe: rowProbe, file: file, line: line)
        }
        assertNoInteractiveOverlap(snapshot, file: file, line: line)
    }

    /// A selection on regular width: the detail column tiles beside the list
    /// and replaces the placeholder.
    func assertSplitTiled(
        _ snapshot: LayoutSnapshot, file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let size = snapshot.size
        let list = try snapshot.frame("split.list", file: file, line: line)
        let detail = try snapshot.frame("split.detail", file: file, line: line)
        XCTAssertLessThanOrEqual(list.maxX, detail.minX + 1, "list | detail must tile at \(size)", file: file, line: line)
        XCTAssertGreaterThan(detail.width, 0, file: file, line: line)
        XCTAssertNil(snapshot.frames["split.placeholder"], "placeholder still shown at \(size)", file: file, line: line)
        assertNoInteractiveOverlap(snapshot, file: file, line: line)
    }
}
