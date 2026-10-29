import SwiftUI
import XCTest
@testable import FinancialManagement

/// D2.1: Accounts pushes on compact (unchanged) and tiles list | detail on
/// regular width, with a placeholder until an account is selected.
@MainActor
final class AccountsSplitLayoutTests: XCTestCase {
    /// FixtureStore's first account, "BCA Tahapan".
    private let bca = UUID(uuidString: "0000f1c7-0001-4000-8000-000000000001")!

    override func setUp() async throws {
        try XCTSkipUnless(FixtureMode.isEnabled, "Layout tests need DUO_FIXTURES=1.")
    }

    private func render(selected: UUID?, at size: LayoutSize) async throws -> LayoutSnapshot {
        let appState = AppState()
        await appState.loadCurrencyData()
        return try await LayoutHarness.render(
            SplitRootContainer { AccountListView(selectedAccountId: selected) }
                .environment(appState)
                .environment(ThemeManager()),
            at: size,
            until: { frames in
                frames["accounts.row.BCA Tahapan"] != nil
                    && (selected == nil || frames["split.detail"] != nil)
            }
        )
    }

    func testListWithNothingSelected() async throws {
        for size in LayoutSize.all {
            let snapshot = try await render(selected: nil, at: size)
            attach(snapshot, name: "accounts")
            XCTAssertNotNil(snapshot.frames["accounts.row.BCA Tahapan"], "accounts never loaded at \(size)")
            XCTAssertNil(snapshot.frames["split.detail"], "\(size)")

            if size.horizontal == .regular {
                let list = try snapshot.frame("split.list")
                let placeholder = try snapshot.frame("split.placeholder")
                XCTAssertLessThanOrEqual(list.maxX, placeholder.minX + 1, "\(size)")
            } else {
                XCTAssertNil(snapshot.frames["split.list"], "\(size)")
                try assertCompactContentWidth(snapshot, probe: "accounts.row.BCA Tahapan")
            }
            assertNoInteractiveOverlap(snapshot)
        }
    }

    func testRegularTilesTheSelectedAccount() async throws {
        for size in LayoutSize.all where size.horizontal == .regular {
            let snapshot = try await render(selected: bca, at: size)
            attach(snapshot, name: "accounts-detail")
            let list = try snapshot.frame("split.list")
            let detail = try snapshot.frame("split.detail")
            XCTAssertLessThanOrEqual(list.maxX, detail.minX + 1, "\(size)")
            XCTAssertNil(snapshot.frames["split.placeholder"], "\(size)")
            assertNoInteractiveOverlap(snapshot)
        }
    }
}
