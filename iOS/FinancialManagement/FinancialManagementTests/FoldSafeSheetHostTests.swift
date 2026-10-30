import SwiftUI
import XCTest
@testable import FinancialManagement

/// D5.1: `FoldSafeSheetHost` keeps a sheet open when the screen that opened it
/// is replaced, and tells the new screen to reload when it closes.
@MainActor
final class FoldSafeSheetHostTests: XCTestCase {
    private let owner = UUID()

    private func present(on host: FoldSafeSheetHost, onClose: @escaping () -> Void = {}) {
        host.present(owner: owner, content: AnyView(EmptyView()), onClose: onClose)
    }

    func testClosingClearsTheOwnersBinding() {
        let host = FoldSafeSheetHost()
        var closed = 0
        present(on: host) { closed += 1 }

        host.sheetClosed()

        XCTAssertNil(host.presentation)
        XCTAssertEqual(closed, 1)
        XCTAssertEqual(host.foldedSheetsClosed, 0)
    }

    func testSheetOutlivesItsOwnerAndAsksForAReload() {
        let host = FoldSafeSheetHost()
        present(on: host)

        host.ownerDisappeared(owner)
        XCTAssertNotNil(host.presentation)
        XCTAssertEqual(host.foldedSheetsClosed, 0, "reload only once the sheet closes")

        host.sheetClosed()
        XCTAssertEqual(host.foldedSheetsClosed, 1)
    }

    func testOnlyTheOwnerCanDismiss() {
        let host = FoldSafeSheetHost()
        present(on: host)

        host.dismiss(owner: UUID())
        XCTAssertNotNil(host.presentation)

        host.dismiss(owner: owner)
        XCTAssertNil(host.presentation)
    }

    func testAnotherScreenLeavingDoesNotMarkTheSheetFolded() {
        let host = FoldSafeSheetHost()
        present(on: host)

        host.ownerDisappeared(UUID())
        host.sheetClosed()

        XCTAssertEqual(host.foldedSheetsClosed, 0)
    }

    func testAReopenedSheetStartsUnfolded() {
        let host = FoldSafeSheetHost()
        present(on: host)
        host.ownerDisappeared(owner)
        host.sheetClosed()

        present(on: host)
        host.sheetClosed()

        XCTAssertEqual(host.foldedSheetsClosed, 1)
    }
}
