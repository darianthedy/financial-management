import SwiftUI
import XCTest
@testable import FinancialManagement

/// Folds and rotations under a live tab, as the app's root hosts it
/// (`SplitRootContainer(storageKey:detail:)` with the root-owned
/// `SplitSelectionStore`): list | detail on the inner display in landscape;
/// the outer display opens on the list and keeps the selection; unfolding
/// brings it back beside the list; rotating to portrait pushes it.
@MainActor
final class FoldRestoreLayoutTests: XCTestCase {
    @Observable
    final class Display {
        var size: LayoutSize = .innerLandscape
    }

    private struct Root<Content: View>: View {
        let display: Display
        @ViewBuilder var content: Content

        var body: some View {
            content
                .environment(\.horizontalSizeClass, display.size.horizontal)
                .environment(\.verticalSizeClass, display.size.vertical)
        }
    }

    private let topUp = UUID(uuidString: "0000f1c7-0006-4000-8000-00000000000c")!
    private let bca = UUID(uuidString: "0000f1c7-0001-4000-8000-000000000001")!

    override func setUp() async throws {
        try XCTSkipUnless(FixtureMode.isEnabled, "Layout tests need DUO_FIXTURES=1.")
    }

    private func poll(_ timeout: Duration = .seconds(8), until done: () -> Bool) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !done(), clock.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    /// Selects `storedID` in the tiled split, then folds and unfolds
    /// `times` times and finally rotates to portrait.
    private func foldRepeatedly<Content: View, Detail: View>(
        selecting storedID: String, key: String, row: String, times: Int = 3,
        @ViewBuilder detail: @escaping (String, @escaping () -> Void) -> Detail,
        @ViewBuilder _ content: () -> Content
    ) async throws {
        let appState = AppState()
        await appState.loadCurrencyData()
        let display = Display()
        let store = SplitSelectionStore()
        // As if picked on the inner display in this run.
        store.set(storedID, for: key)

        let host = UIHostingController(
            rootView: Root(display: display) {
                SplitRootContainer(storageKey: key, detail: detail, content: content)
            }
            .environment(\.splitSelectionStore, store)
            .environment(\.transactionDrafts, TransactionEditorDrafts())
            .environment(appState)
            .environment(ThemeManager())
        )
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: LayoutSize.innerLandscape.size)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        let recorder = LayoutProbeRecorder.shared
        recorder.reset()
        recorder.isRecording = true
        recorder.dropsDisappeared = true
        defer {
            recorder.isRecording = false
            recorder.dropsDisappeared = false
        }

        func show(_ size: LayoutSize) {
            display.size = size
            window.frame = CGRect(origin: .zero, size: size.size)
        }
        let selectedID = SplitSelectionRule.Stored(rawValue: storedID)?.id

        try await poll { recorder.records["split.detail"] != nil && recorder.records["split.list"] != nil }
        XCTAssertNotNil(recorder.records["split.detail"], "never tiled the selection before the fold")

        for round in 1...times {
            show(.outerPortrait)
            try await poll { recorder.records["split.list"] == nil && recorder.records[row] != nil }
            try await Task.sleep(for: .milliseconds(1000))
            XCTAssertNotNil(recorder.records[row], "fold \(round): the outer display didn't show the list")
            XCTAssertNil(recorder.records["split.detail"], "fold \(round): the outer display opened a detail")
            let kept = store.value(for: key).flatMap { SplitSelectionRule.Stored(rawValue: $0)?.id }
            XCTAssertEqual(kept, selectedID, "fold \(round): the selection wasn't kept for the inner display")

            show(.innerLandscape)
            try await poll { recorder.records["split.detail"] != nil && recorder.records["split.list"] != nil }
            XCTAssertNotNil(recorder.records["split.detail"], "unfold \(round): the selection didn't come back")
            guard recorder.records["split.detail"] != nil else { return }
        }

        // Rotating to portrait pushes the selection.
        show(.innerPortrait)
        try await poll { recorder.records["split.detail"] != nil && recorder.records["split.list"] == nil }
        XCTAssertNotNil(recorder.records["split.detail"], "rotating to portrait didn't push the selection")
    }

    func testAccountsKeepTheSelectionThroughFolds() async throws {
        try await foldRepeatedly(selecting: "t:\(bca.uuidString)", key: "accounts", row: "accounts.row.BCA Tahapan") { id, _ in
            if let accountId = UUID(uuidString: id) { AccountDetailView(accountId: accountId) }
        } _: {
            AccountListView()
        }
    }

    func testTransactionsKeepTheSelectionThroughFolds() async throws {
        let model = TransactionListViewModel()
        let drafts = TransactionEditorDrafts()
        try await foldRepeatedly(
            selecting: "t:\(topUp.uuidString)", key: "transactions", row: "transactions.row.Top up Jenius"
        ) { id, close in
            if let transactionId = UUID(uuidString: id) {
                TransactionDetailScreen(id: transactionId, model: model, drafts: drafts, onClose: close)
            }
        } _: {
            TransactionListView(model: model, isTabRoot: true)
        }
    }
}
