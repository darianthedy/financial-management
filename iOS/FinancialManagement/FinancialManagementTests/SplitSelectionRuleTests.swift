import XCTest
@testable import FinancialManagement

/// D2.0: the selection rule behind `.splitDetail` — restore, clear, keep.
final class SplitSelectionRuleTests: XCTestCase {
    private typealias Rule = SplitSelectionRule
    private let ids = ["a", "b", "c"]

    func testStoredRoundTrips() {
        for wasTiled in [true, false] {
            let stored = Rule.Stored(id: "id:with:colons", wasTiled: wasTiled)
            XCTAssertEqual(Rule.Stored(rawValue: stored.rawValue), stored)
        }
        XCTAssertNil(Rule.Stored(rawValue: nil))
        XCTAssertNil(Rule.Stored(rawValue: "t:"))
        XCTAssertNil(Rule.Stored(rawValue: "x:a"))
        XCTAssertNil(Rule.Stored(rawValue: "legacy"))
    }

    func testEmptyListChangesNothing() {
        XCTAssertEqual(Rule.resolve(selected: "b", stored: nil, available: [], restoring: true, isTiled: true), "b")
        XCTAssertNil(Rule.resolve(selected: nil, stored: .init(id: "b", wasTiled: true), available: [], restoring: true, isTiled: true))
    }

    func testListedSelectionIsKept() {
        XCTAssertEqual(Rule.resolve(selected: "b", stored: .init(id: "c", wasTiled: true), available: ids, restoring: true, isTiled: true), "b")
    }

    func testUnlistedSelectionIsCleared() {
        XCTAssertNil(Rule.resolve(selected: "z", stored: nil, available: ids, restoring: false, isTiled: true))
        XCTAssertNil(Rule.resolve(selected: "z", stored: nil, available: ids, restoring: false, isTiled: false))
    }

    func testRestoresIntoATiledSplit() {
        for wasTiled in [true, false] {
            XCTAssertEqual(
                Rule.resolve(selected: nil, stored: .init(id: "c", wasTiled: wasTiled), available: ids, restoring: true, isTiled: true),
                "c"
            )
        }
    }

    func testRestoresFromTiledIntoAPush() {
        // Folding the Duo closed: the tiled selection becomes the pushed detail.
        XCTAssertEqual(Rule.resolve(selected: nil, stored: .init(id: "c", wasTiled: true), available: ids, restoring: true, isTiled: false), "c")
    }

    func testNeverRestoresPushIntoPush() {
        // Relaunching on iPhone, or More popped to its root: no surprise push.
        XCTAssertNil(Rule.resolve(selected: nil, stored: .init(id: "c", wasTiled: false), available: ids, restoring: true, isTiled: false))
    }

    func testRestoresOnlyOnce() {
        XCTAssertNil(Rule.resolve(selected: nil, stored: .init(id: "c", wasTiled: true), available: ids, restoring: false, isTiled: true))
    }

    func testStoredSelectionMustStillBeListed() {
        XCTAssertNil(Rule.resolve(selected: nil, stored: .init(id: "z", wasTiled: true), available: ids, restoring: true, isTiled: true))
    }

    func testListColumnWidth() {
        XCTAssertEqual(SplitColumns.listWidth(for: 669), 300)   // inner portrait
        XCTAssertEqual(SplitColumns.listWidth(for: 951), 380)   // inner landscape
        XCTAssertEqual(SplitColumns.listWidth(for: 1366), 420)
        XCTAssertEqual(SplitColumns.listWidth(for: 500), 300)
    }

    /// Device test (build 143): in book posture the sidebar fills the leading
    /// region, leaving ~392 pt, and the detail column was crushed to ~90 pt.
    func testTilesOnlyWhenBothColumnsFit() {
        XCTAssertTrue(SplitColumns.tiles(width: 867))    // inner landscape, rail only
        XCTAssertTrue(SplitColumns.tiles(width: 669))    // inner portrait / tent
        XCTAssertTrue(SplitColumns.tiles(width: 660))
        XCTAssertFalse(SplitColumns.tiles(width: 659))
        XCTAssertFalse(SplitColumns.tiles(width: 585))   // flat with the sidebar (build 144)
        XCTAssertFalse(SplitColumns.tiles(width: 392))   // book posture with the sidebar (build 143)
    }

    func testListColumnEndsOnTheFoldInBookPosture() {
        XCTAssertEqual(SplitColumns.listWidth(for: 867, fold: .book(divisionX: 475.5)), 476)
    }

    func testListColumnIgnoresAFoldThatStarvesAColumn() {
        // The fold at the container's edge (the sidebar fills the leading region).
        XCTAssertEqual(SplitColumns.listWidth(for: 867, fold: .book(divisionX: 0)), 347)
        XCTAssertEqual(SplitColumns.listWidth(for: 700, fold: .book(divisionX: 500)), 300)
        XCTAssertEqual(SplitColumns.listWidth(for: 867, fold: .tent(divisionY: 475)), 347)
    }
}
