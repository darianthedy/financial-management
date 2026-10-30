import SwiftUI
import XCTest
@testable import FinancialManagement

/// D5.1: a sheet survives a trait flip with its draft intact, even though the
/// flip re-creates the screen that opened it (`SplitRootContainer` branches on
/// size class). The control shows a plain `.sheet` doesn't.
@MainActor
final class SheetFoldLayoutTests: XCTestCase {
    /// Drives the flip and records what the sheet saw.
    @Observable
    private final class Scenario {
        var sizeClass: UserInterfaceSizeClass = .compact
        var shouldOpen = true
        var draftsSeen: [UUID] = []
        var disappearances = 0
    }

    /// Stands in for a form: its draft is `@State`, like the real sheets.
    private struct DraftSheet: View {
        let scenario: Scenario
        @State private var draft = UUID()

        var body: some View {
            Text("Draft")
                .onAppear { scenario.draftsSeen.append(draft) }
                .onDisappear { scenario.disappearances += 1 }
        }
    }

    private struct Screen: View {
        let scenario: Scenario
        let foldSafe: Bool
        @State private var showing = false

        var body: some View {
            Group {
                if foldSafe {
                    Text("Screen").foldSafeSheet(isPresented: $showing) {
                        DraftSheet(scenario: scenario)
                    }
                } else {
                    Text("Screen").sheet(isPresented: $showing) {
                        DraftSheet(scenario: scenario)
                    }
                }
            }
            .onAppear {
                // Once only: the flip re-creates this screen.
                guard scenario.shouldOpen else { return }
                scenario.shouldOpen = false
                showing = true
            }
        }
    }

    private struct Root: View {
        let scenario: Scenario
        let foldSafe: Bool

        var body: some View {
            SplitRootContainer { Screen(scenario: scenario, foldSafe: foldSafe) }
                .hostsFoldSafeSheets()
                .environment(\.horizontalSizeClass, scenario.sizeClass)
        }
    }

    private func poll(_ timeout: Duration = .seconds(5), until done: () -> Bool) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !done(), clock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    /// Opens the sheet on compact, flips to regular, and returns the scenario.
    private func runFlip(foldSafe: Bool) async throws -> Scenario {
        let scenario = Scenario()
        let host = UIHostingController(rootView: Root(scenario: scenario, foldSafe: foldSafe))
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        try await poll { !scenario.draftsSeen.isEmpty }
        XCTAssertEqual(scenario.draftsSeen.count, 1, "the sheet never opened")

        scenario.sizeClass = .regular
        try await Task.sleep(for: .seconds(1))
        return scenario
    }

    func testFoldSafeSheetKeepsItsDraft() async throws {
        let scenario = try await runFlip(foldSafe: true)
        XCTAssertEqual(scenario.draftsSeen.count, 1, "the sheet was re-created")
        XCTAssertEqual(scenario.disappearances, 0, "the sheet closed")
    }

    func testPlainSheetLosesItsDraft() async throws {
        let scenario = try await runFlip(foldSafe: false)
        XCTAssertEqual(scenario.disappearances, 1, "expected the flip to close a plain sheet")
    }
}
