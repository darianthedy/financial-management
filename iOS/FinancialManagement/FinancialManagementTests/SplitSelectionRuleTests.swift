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
}
