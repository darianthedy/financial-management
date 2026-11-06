import XCTest
@testable import FinancialManagement

/// The root-owned selection a fold or a rotation restores from.
@MainActor
final class SplitSelectionStoreTests: XCTestCase {
    func testNothingStoredFallsBackToTheScene() {
        let store = SplitSelectionStore()
        XCTAssertNil(store.value(for: "transactions"))
    }

    func testKeepsTheLatestSelection() {
        let store = SplitSelectionStore()
        store.set("t:a", for: "transactions")
        store.set("s:b", for: "transactions")
        XCTAssertEqual(store.value(for: "transactions"), .some("s:b"))
        XCTAssertNil(store.value(for: "accounts"))
    }

    /// Cleared (Back) is remembered as cleared, not as "nothing stored", so
    /// a stale scene value can't bring it back.
    func testClearedStaysCleared() {
        let store = SplitSelectionStore()
        store.set("t:a", for: "budgets")
        store.set(nil, for: "budgets")
        XCTAssertEqual(store.value(for: "budgets"), .some(nil))
    }
}
