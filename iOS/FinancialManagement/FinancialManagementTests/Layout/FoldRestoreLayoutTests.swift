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

    /// Selects `storedID` in the tiled split, folds, and returns the probes
    /// recorded on the outer display.
    private func fold<Content: View>(
        selecting storedID: String, key: String, @ViewBuilder _ content: () -> Content
    ) async throws -> [String: LayoutProbeRecorder.Record] {
        let appState = AppState()
        await appState.loadCurrencyData()
        let display = Display()
        let store = SplitSelectionStore()
        // As if picked on the inner display in this run.
        store.set(storedID, for: key)

        let host = UIHostingController(
            rootView: Root(display: display) {
                SplitRootContainer(storageKey: key, content: content)
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

        try await poll { recorder.records["split.detail"] != nil && recorder.records["split.list"] != nil }
        XCTAssertNotNil(recorder.records["split.list"], "never tiled before the fold")

        // The fold: the outer display's size and compact width.
        print("SPLIT-TRACE ---- fold \(key)")
        recorder.reset()
        display.size = .outerPortrait
        window.frame = CGRect(origin: .zero, size: LayoutSize.outerPortrait.size)
        try await poll { recorder.records["split.detail"] != nil }
        // Let any late reload or reconcile run: a probe that leaves the
        // screen drops out of the records.
        try await Task.sleep(for: .seconds(3))
        print("SPLIT-TRACE ---- end \(key) stored=\(String(describing: store.value(for: key))) probes=\(recorder.records.keys.sorted())")
        return recorder.records
    }

    func testAccountsOpensOnTheDetailAfterAFold() async throws {
        let records = try await fold(selecting: "t:\(bca.uuidString)", key: "accounts") {
            AccountListView()
        }
        XCTAssertNotNil(records["split.detail"], "the outer display showed the list, not the account")
        XCTAssertNil(records["split.list"])
    }

    func testTransactionsOpensOnTheDetailAfterAFold() async throws {
        let model = TransactionListViewModel()
        let records = try await fold(selecting: "t:\(topUp.uuidString)", key: "transactions") {
            TransactionListView(model: model, isTabRoot: true)
        }
        XCTAssertNotNil(records["split.detail"], "the outer display showed the list, not the transaction")
        XCTAssertNotNil(records["transactionDetail"], "the transaction's detail isn't on screen")
    }
}
