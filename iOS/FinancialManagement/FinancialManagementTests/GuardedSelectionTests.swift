import XCTest
@testable import FinancialManagement

/// D2.6 (shared with D3.1): switching rows never silently drops unsaved edits.
final class GuardedSelectionTests: XCTestCase {
    func testCleanEditorSwitchesImmediately() {
        var guarded = GuardedSelection<String>(selection: "a")
        guarded.request("b")
        XCTAssertEqual(guarded.selection, "b")
        XCTAssertFalse(guarded.isConfirmingDiscard)
    }

    func testDirtyEditorAsksFirst() {
        var guarded = GuardedSelection<String>(selection: "a")
        guarded.isDirty = true
        guarded.request("b")
        XCTAssertEqual(guarded.selection, "a")
        XCTAssertTrue(guarded.isConfirmingDiscard)
    }

    func testDiscardGoesWhereAsked() {
        var guarded = GuardedSelection<String>(selection: "a")
        guarded.isDirty = true
        guarded.request("b")
        guarded.discardAndContinue()
        XCTAssertEqual(guarded.selection, "b")
        XCTAssertFalse(guarded.isDirty)
        XCTAssertFalse(guarded.isConfirmingDiscard)
    }

    func testDiscardCanDeselect() {
        var guarded = GuardedSelection<String>(selection: "a")
        guarded.isDirty = true
        guarded.request(nil)
        XCTAssertTrue(guarded.isConfirmingDiscard)
        guarded.discardAndContinue()
        XCTAssertNil(guarded.selection)
    }

    func testKeepEditingStays() {
        var guarded = GuardedSelection<String>(selection: "a")
        guarded.isDirty = true
        guarded.request("b")
        guarded.keepEditing()
        XCTAssertEqual(guarded.selection, "a")
        XCTAssertTrue(guarded.isDirty)
        XCTAssertFalse(guarded.isConfirmingDiscard)
    }

    func testReselectingTheSameRowIsANoOp() {
        var guarded = GuardedSelection<String>(selection: "a")
        guarded.isDirty = true
        guarded.request("a")
        XCTAssertFalse(guarded.isConfirmingDiscard)
    }

    func testCloseClearsEverything() {
        var guarded = GuardedSelection<String>(selection: "a")
        guarded.isDirty = true
        guarded.close()
        XCTAssertNil(guarded.selection)
        XCTAssertFalse(guarded.isDirty)
    }
}
