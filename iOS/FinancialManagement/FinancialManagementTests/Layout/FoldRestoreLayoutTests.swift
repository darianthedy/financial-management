import SwiftUI
import XCTest
@testable import FinancialManagement

/// A fold under a live tab: list | detail on the inner display in landscape,
/// then the outer display, which must open on the selected detail (pushed),
/// as the app's root hosts it (`SplitRootContainer(storageKey:)` with the
/// root-owned `SplitSelectionStore`).
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
    /// `times` times, checking after each fold that the outer display shows
    /// the detail.
    private func foldRepeatedly<Content: View, Detail: View>(
        selecting storedID: String, key: String, times: Int = 4,
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

        try await poll { recorder.records["split.detail"] != nil && recorder.records["split.list"] != nil }
        XCTAssertNotNil(recorder.records["split.list"], "never tiled before the fold")

        for round in 1...times {
            show(.outerPortrait)
            try await poll { recorder.records["split.detail"] != nil && recorder.records["split.list"] == nil }
            // Let any late reload or reconcile run: a probe that leaves the
            // screen drops out of the records.
            try await Task.sleep(for: .milliseconds(1500))
            XCTAssertNotNil(
                recorder.records["split.detail"],
                "fold \(round): the outer display showed the list. stored=\(String(describing: store.value(for: key)))"
            )
            guard recorder.records["split.detail"] != nil else { return }

            show(.innerLandscape)
            try await poll { recorder.records["split.list"] != nil }
            try await Task.sleep(for: .milliseconds(500))
        }
    }

    func testAccountsOpensOnTheDetailAfterAFold() async throws {
        try await foldRepeatedly(selecting: "t:\(bca.uuidString)", key: "accounts") { id, _ in
            if let accountId = UUID(uuidString: id) { AccountDetailView(accountId: accountId) }
        } _: {
            AccountListView()
        }
    }

    func testTransactionsOpensOnTheDetailAfterAFold() async throws {
        let model = TransactionListViewModel()
        let drafts = TransactionEditorDrafts()
        try await foldRepeatedly(selecting: "t:\(topUp.uuidString)", key: "transactions") { id, close in
            if let transactionId = UUID(uuidString: id) {
                TransactionDetailScreen(id: transactionId, model: model, drafts: drafts, onClose: close)
            }
        } _: {
            TransactionListView(model: model, isTabRoot: true)
        }
    }
}
